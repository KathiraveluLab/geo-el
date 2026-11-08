defmodule GeoEl.Adventure.BISE do
  @moduledoc """
  Bounded Input State Enforcement (BISE) guardrail functions for spherical domain clamping,
  viewport rotation sanitization, and cartographic ring verification.
  """

  alias GeoEl.Globe.Coord

  @max_rotation_delta_deg 45.0
  @max_player_name_length 40

  @doc """
  Sanitizes a player's explorer name by removing control characters, normalizing whitespace,
  and bounding length to `[1, 40]` graphemes. Defaults to `"Anonymous Explorer"` when blank.
  """
  @spec sanitize_player_name(term()) :: String.t()
  def sanitize_player_name(name) when is_binary(name) do
    cleaned =
      name
      |> String.replace(~r/[\x00-\x1F\x7F]+/u, " ")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()
      |> String.slice(0, @max_player_name_length)

    if cleaned == "" do
      "Anonymous Explorer"
    else
      cleaned
    end
  end

  def sanitize_player_name(_), do: "Anonymous Explorer"

  @doc """
  Clamps a normalized radial offset ratio `rho / R` into the closed interval `[0.0, 1.0]`.
  Prevents floating-point boundary inaccuracies near the horizon limb from triggering `:math.asin/1` faults.
  """
  @spec clamp_radial_ratio(number()) :: float()
  def clamp_radial_ratio(ratio) when is_number(ratio) do
    val = ratio * 1.0

    cond do
      val > 1.0 -> 1.0
      val < 0.0 -> 0.0
      true -> val
    end
  end

  @doc """
  Clamps a trigonometric sine or cosine argument into `[-1.0, 1.0]`.
  """
  @spec clamp_trig_domain(number()) :: float()
  def clamp_trig_domain(value) when is_number(value) do
    val = value * 1.0

    cond do
      val > 1.0 -> 1.0
      val < -1.0 -> -1.0
      true -> val
    end
  end

  @doc """
  Sanitizes and clamps angular camera rotation deltas so malformed client drag payloads cannot
  destabilize camera orientation.
  """
  @spec sanitize_rotation_delta(number(), number()) :: {float(), float()}
  def sanitize_rotation_delta(dlat, dlon) when is_number(dlat) and is_number(dlon) do
    {
      clamp_delta(dlat * 1.0, @max_rotation_delta_deg),
      clamp_delta(dlon * 1.0, @max_rotation_delta_deg)
    }
  end

  def sanitize_rotation_delta(_, _), do: {0.0, 0.0}

  @doc """
  Verifies that a cartographic polygon ring has at least four vertices and closes on its start coordinate.
  """
  @spec valid_closed_ring?([Coord.t()]) :: boolean()
  def valid_closed_ring?(coords) when is_list(coords) and length(coords) >= 4 do
    first = List.first(coords)
    last = List.last(coords)

    all_valid =
      Enum.all?(coords, fn
        %Coord{lat: lat, lon: lon} ->
          lat >= -90.0 and lat <= 90.0 and lon >= -180.0 and lon <= 180.0

        _ ->
          false
      end)

    all_valid and abs(first.lat - last.lat) < 1.0e-4 and abs(first.lon - last.lon) < 1.0e-4
  end

  def valid_closed_ring?(_), do: false

  defp clamp_delta(val, limit) when val > limit, do: limit
  defp clamp_delta(val, limit) when val < -limit, do: -limit
  defp clamp_delta(val, _limit), do: val
end
