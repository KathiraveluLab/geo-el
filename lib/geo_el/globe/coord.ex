defmodule GeoEl.Globe.Coord do
  @moduledoc """
  Represents a spherical Earth coordinate with latitude and longitude in degrees.
  """

  @enforce_keys [:lat, :lon]
  defstruct [:lat, :lon]

  @type t :: %__MODULE__{
          lat: float(),
          lon: float()
        }

  @spec new(number(), number()) :: t()
  def new(lat, lon) when is_number(lat) and is_number(lon) do
    %__MODULE__{
      lat: clamp_lat(lat * 1.0),
      lon: normalize_lon(lon * 1.0)
    }
  end

  @spec clamp_lat(float()) :: float()
  def clamp_lat(lat) when lat > 90.0, do: 90.0
  def clamp_lat(lat) when lat < -90.0, do: -90.0
  def clamp_lat(lat), do: lat

  @spec normalize_lon(float()) :: float()
  def normalize_lon(lon) do
    wrapped = :math.fmod(lon + 180.0, 360.0)

    adjusted =
      if wrapped < 0.0 do
        wrapped + 360.0
      else
        wrapped
      end

    adjusted - 180.0
  end
end

