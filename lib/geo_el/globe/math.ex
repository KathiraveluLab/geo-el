defmodule GeoEl.Globe.Math do
  @moduledoc """
  Spherical trigonometry and geodesic distance operations on the Earth sphere.
  """

  alias GeoEl.Globe.Coord

  @earth_radius_km 6371.0088

  @spec earth_radius_km() :: float()
  def earth_radius_km, do: @earth_radius_km

  @spec deg_to_rad(number()) :: float()
  def deg_to_rad(deg), do: deg * :math.pi() / 180.0

  @spec rad_to_deg(number()) :: float()
  def rad_to_deg(rad), do: rad * 180.0 / :math.pi()

  @doc """
  Computes the cosine of the central angle between a surface point and the camera center.
  Positive values indicate visibility on the front hemisphere.
  """
  @spec cos_central_angle(Coord.t(), Coord.t()) :: float()
  def cos_central_angle(%Coord{} = point, %Coord{} = camera) do
    phi = deg_to_rad(point.lat)
    lambda = deg_to_rad(point.lon)
    phi0 = deg_to_rad(camera.lat)
    lambda0 = deg_to_rad(camera.lon)

    :math.sin(phi0) * :math.sin(phi) +
      :math.cos(phi0) * :math.cos(phi) * :math.cos(lambda - lambda0)
  end

  @doc """
  Returns true when the point resides on the visible orthographic hemisphere.
  """
  @spec visible?(Coord.t(), Coord.t()) :: boolean()
  def visible?(%Coord{} = point, %Coord{} = camera) do
    cos_central_angle(point, camera) >= 0.0
  end

  @doc """
  Computes the great-circle Haversine arc distance in kilometers between two coordinates.
  """
  @spec haversine_distance(Coord.t(), Coord.t()) :: float()
  def haversine_distance(%Coord{} = origin, %Coord{} = target) do
    phi1 = deg_to_rad(origin.lat)
    phi2 = deg_to_rad(target.lat)
    delta_phi = deg_to_rad(target.lat - origin.lat)
    delta_lambda = deg_to_rad(target.lon - origin.lon)

    sin_half_phi = :math.sin(delta_phi / 2.0)
    sin_half_lambda = :math.sin(delta_lambda / 2.0)

    a =
      sin_half_phi * sin_half_phi +
        :math.cos(phi1) * :math.cos(phi2) * sin_half_lambda * sin_half_lambda

    clamped_a = min(1.0, max(0.0, a))
    delta_sigma = 2.0 * :math.atan2(:math.sqrt(clamped_a), :math.sqrt(max(0.0, 1.0 - clamped_a)))

    @earth_radius_km * delta_sigma
  end

  @doc """
  Generates intermediate coordinates along the great-circle geodesic arc between two points.
  """
  @spec interpolate_arc(Coord.t(), Coord.t(), pos_integer()) :: [Coord.t()]
  def interpolate_arc(%Coord{} = origin, %Coord{} = target, segments \\ 24)
      when is_integer(segments) and segments > 0 do
    p1 = to_cartesian(origin)
    p2 = to_cartesian(target)
    dot = clamp_unit(dot_product(p1, p2))
    omega = :math.acos(dot)

    if omega < 1.0e-6 do
      [origin, target]
    else
      sin_omega = :math.sin(omega)

      Enum.map(0..segments, fn step ->
        fraction = step / segments
        w1 = :math.sin((1.0 - fraction) * omega) / sin_omega
        w2 = :math.sin(fraction * omega) / sin_omega
        {x1, y1, z1} = p1
        {x2, y2, z2} = p2
        from_cartesian({w1 * x1 + w2 * x2, w1 * y1 + w2 * y2, w1 * z1 + w2 * z2})
      end)
    end
  end

  defp to_cartesian(%Coord{} = coord) do
    phi = deg_to_rad(coord.lat)
    lambda = deg_to_rad(coord.lon)
    cos_phi = :math.cos(phi)
    {cos_phi * :math.cos(lambda), cos_phi * :math.sin(lambda), :math.sin(phi)}
  end

  defp from_cartesian({x, y, z}) do
    norm = :math.sqrt(x * x + y * y + z * z)

    if norm < 1.0e-9 do
      Coord.new(0.0, 0.0)
    else
      nx = x / norm
      ny = y / norm
      nz = clamp_unit(z / norm)
      lat = rad_to_deg(:math.asin(nz))
      lon = rad_to_deg(:math.atan2(ny, nx))
      Coord.new(lat, lon)
    end
  end

  defp dot_product({x1, y1, z1}, {x2, y2, z2}), do: x1 * x2 + y1 * y2 + z1 * z2

  defp clamp_unit(value) when value > 1.0, do: 1.0
  defp clamp_unit(value) when value < -1.0, do: -1.0
  defp clamp_unit(value), do: value
end
