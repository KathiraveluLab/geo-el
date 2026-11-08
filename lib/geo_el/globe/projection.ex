defmodule GeoEl.Globe.Projection do
  @moduledoc """
  Forward and inverse orthographic spherical projections with Bounded Input State Enforcement (BISE).
  """

  alias GeoEl.Adventure.BISE
  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Math

  @doc """
  Projects a spherical coordinate onto 2D Cartesian viewport offsets relative to the globe center.
  Returns `{:ok, {x, y, cos_c}}` if visible on the front hemisphere, or `:occluded` if on the far side.
  """
  @spec forward(Coord.t(), Coord.t(), number()) ::
          {:ok, {float(), float(), float()}} | :occluded
  def forward(%Coord{} = point, %Coord{} = camera, radius) when is_number(radius) and radius > 0 do
    cos_c = Math.cos_central_angle(point, camera)

    if cos_c < 0.0 do
      :occluded
    else
      phi = Math.deg_to_rad(point.lat)
      lambda = Math.deg_to_rad(point.lon)
      phi0 = Math.deg_to_rad(camera.lat)
      lambda0 = Math.deg_to_rad(camera.lon)

      x = radius * :math.cos(phi) * :math.sin(lambda - lambda0)

      y =
        -radius *
          (:math.cos(phi0) * :math.sin(phi) -
             :math.sin(phi0) * :math.cos(phi) * :math.cos(lambda - lambda0))

      {:ok, {x, y, cos_c}}
    end
  end

  @doc """
  Maps a 2D viewport offset `(x, y)` relative to the globe center back to spherical coordinates.
  Applies BISE radial clamping so clicks near the horizon boundary never trigger arithmetic faults.
  """
  @spec inverse(number(), number(), Coord.t(), number()) :: {:ok, Coord.t(), float()}
  def inverse(x, y, %Coord{} = camera, radius)
      when is_number(x) and is_number(y) and is_number(radius) and radius > 0 do
    fx = x * 1.0
    fy = y * 1.0
    fr = radius * 1.0
    rho = :math.sqrt(fx * fx + fy * fy)

    if rho < 1.0e-9 do
      {:ok, camera, 1.0}
    else
      u_hat = BISE.clamp_radial_ratio(rho / fr)
      c = :math.asin(u_hat)
      cos_c = :math.cos(c)
      sin_c = :math.sin(c)

      phi0 = Math.deg_to_rad(camera.lat)
      lambda0 = Math.deg_to_rad(camera.lon)

      sin_phi =
        BISE.clamp_trig_domain(
          cos_c * :math.sin(phi0) + -fy * sin_c * :math.cos(phi0) / rho
        )

      phi = :math.asin(sin_phi)

      lambda =
        lambda0 +
          :math.atan2(
            fx * sin_c,
            rho * :math.cos(phi0) * cos_c + fy * :math.sin(phi0) * sin_c
          )

      coord = Coord.new(Math.rad_to_deg(phi), Math.rad_to_deg(lambda))
      {:ok, coord, cos_c}
    end
  end

  @doc """
  Serializes a sequence of spherical coordinates into an SVG path string (`M ... L ...`),
  clipping segments that cross behind the visible hemisphere.
  """
  @spec project_path([Coord.t()], Coord.t(), number(), {number(), number()}) :: String.t()
  def project_path(coords, %Coord{} = camera, radius, {cx, cy} \\ {0.0, 0.0})
      when is_list(coords) do
    {segments, current} =
      Enum.reduce(coords, {[], []}, fn coord, {acc_segments, active_run} ->
        case forward(coord, camera, radius) do
          {:ok, {x, y, _cos_c}} ->
            point_str = "#{ Float.round(cx + x, 2) },#{ Float.round(cy + y, 2) }"
            {acc_segments, [point_str | active_run]}

          :occluded ->
            if active_run == [] do
              {acc_segments, []}
            else
              {[Enum.reverse(active_run) | acc_segments], []}
            end
        end
      end)

    all_segments =
      if current == [] do
        Enum.reverse(segments)
      else
        Enum.reverse([Enum.reverse(current) | segments])
      end

    all_segments
    |> Enum.filter(fn seg -> length(seg) >= 2 end)
    |> Enum.map(fn [first | rest] ->
      "M " <> first <> " L " <> Enum.join(rest, " L ")
    end)
    |> Enum.join(" ")
  end

  @doc """
  Generates projected SVG path strings for meridian and parallel graticule lines.
  """
  @spec graticule_paths(Coord.t(), number(), {number(), number()}) :: [String.t()]
  def graticule_paths(%Coord{} = camera, radius, center \\ {0.0, 0.0}) do
    meridians =
      for lon <- -150..180//30 do
        coords =
          for lat <- -80..80//5 do
            Coord.new(lat, lon)
          end

        project_path(coords, camera, radius, center)
      end

    parallels =
      for lat <- -60..60//30 do
        coords =
          for lon <- -180..180//5 do
            Coord.new(lat, lon)
          end

        project_path(coords, camera, radius, center)
      end

    (meridians ++ parallels)
    |> Enum.reject(&(&1 == ""))
  end
end

