defmodule GeoEl.Globe.WorldData do
  @moduledoc """
  Manages static cartographic continent contours and expedition waypoints in shared constant storage.
  """

  alias GeoEl.Adventure.BISE
  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Waypoint

  @continents_key {__MODULE__, :continents}
  @waypoints_key {__MODULE__, :waypoints}

  @doc """
  Validates static vector contours and waypoints through BISE and stores them in `:persistent_term`.
  """
  @spec load_into_persistent_term!() :: :ok
  def load_into_persistent_term! do
    continents = build_continents()
    waypoints = build_waypoints()

    Enum.each(continents, fn %{name: name, coords: ring} ->
      if not BISE.valid_closed_ring?(ring) do
        raise ArgumentError, "Invalid closed cartographic ring for #{name}"
      end
    end)

    :persistent_term.put(@continents_key, continents)
    :persistent_term.put(@waypoints_key, waypoints)
    :ok
  end

  @spec continents() :: [%{name: String.t(), coords: [Coord.t()]}]
  def continents do
    case :persistent_term.get(@continents_key, nil) do
      nil ->
        load_into_persistent_term!()
        :persistent_term.get(@continents_key)

      data ->
        data
    end
  end

  @spec waypoints() :: [Waypoint.t()]
  def waypoints do
    case :persistent_term.get(@waypoints_key, nil) do
      nil ->
        load_into_persistent_term!()
        :persistent_term.get(@waypoints_key)

      data ->
        data
    end
  end

  defp build_continents do
    [
      %{
        name: "Africa",
        coords:
          ring_from_pairs([
            {37.0, 10.0},
            {32.0, 32.0},
            {12.0, 51.0},
            {-2.0, 41.0},
            {-15.0, 40.0},
            {-34.8, 20.0},
            {-18.0, 12.0},
            {4.0, 9.0},
            {5.0, -8.0},
            {15.0, -17.5},
            {28.0, -13.0},
            {35.8, -5.5},
            {37.0, 10.0}
          ])
      },
      %{
        name: "Eurasia",
        coords:
          ring_from_pairs([
            {36.0, -9.0},
            {43.0, -9.0},
            {48.0, -4.0},
            {54.0, 8.0},
            {60.0, 5.0},
            {71.0, 28.0},
            {70.0, 60.0},
            {73.0, 105.0},
            {66.0, 170.0},
            {52.0, 140.0},
            {35.0, 129.0},
            {22.0, 114.0},
            {1.3, 103.8},
            {16.0, 94.0},
            {22.0, 88.0},
            {8.0, 77.5},
            {25.0, 67.0},
            {12.5, 44.0},
            {31.0, 32.5},
            {38.0, 24.0},
            {41.0, 14.0},
            {43.0, 3.0},
            {36.0, -5.5},
            {36.0, -9.0}
          ])
      },
      %{
        name: "North America",
        coords:
          ring_from_pairs([
            {70.0, -160.0},
            {71.0, -100.0},
            {60.0, -64.0},
            {47.0, -53.0},
            {40.0, -74.0},
            {25.0, -80.0},
            {29.0, -95.0},
            {19.0, -96.0},
            {8.5, -79.5},
            {16.0, -98.0},
            {23.0, -106.0},
            {33.0, -117.0},
            {48.0, -124.5},
            {60.0, -149.0},
            {65.0, -168.0},
            {70.0, -160.0}
          ])
      },
      %{
        name: "South America",
        coords:
          ring_from_pairs([
            {11.0, -75.0},
            {10.0, -62.0},
            {0.0, -50.0},
            {-6.0, -35.0},
            {-23.0, -43.0},
            {-35.0, -54.0},
            {-55.0, -67.0},
            {-53.0, -73.0},
            {-33.0, -71.5},
            {-18.0, -71.0},
            {-12.0, -77.0},
            {-5.0, -81.0},
            {4.0, -77.5},
            {11.0, -75.0}
          ])
      },
      %{
        name: "Australia",
        coords:
          ring_from_pairs([
            {-12.0, 131.0},
            {-11.0, 142.5},
            {-28.0, 153.5},
            {-38.0, 145.0},
            {-35.0, 136.0},
            {-34.0, 115.0},
            {-22.0, 114.0},
            {-15.0, 124.0},
            {-12.0, 131.0}
          ])
      },
      %{
        name: "Antarctica",
        coords:
          ring_from_pairs([
            {-65.0, -60.0},
            {-70.0, 0.0},
            {-67.0, 60.0},
            {-66.0, 120.0},
            {-72.0, 175.0},
            {-74.0, -130.0},
            {-65.0, -60.0}
          ])
      }
    ]
  end

  defp build_waypoints do
    [
      %Waypoint{
        id: "wp-greenwich",
        name: "Royal Observatory Greenwich",
        region: "Western Europe",
        coord: Coord.new(51.4769, 0.0005),
        tier1_clue:
          "Begin your calibration where the Prime Meridian divides the Eastern and Western hemispheres along a tidal river.",
        tier2_clue:
          "Located in southeastern Great Britain on the southern bank of the River Thames.",
        tier3_clue: "Target telemetry: latitude 51.5 degrees North, longitude 0.0 degrees."
      },
      %Waypoint{
        id: "wp-quito",
        name: "Mitad del Mundo, Quito",
        region: "Andean South America",
        coord: Coord.new(-0.0022, -78.4558),
        tier1_clue:
          "Plot a course to the high-altitude volcanic basin where the Equator crosses the spine of the Andes.",
        tier2_clue:
          "This capital basin sits at 2,850 meters elevation near the Pichincha stratovolcano in northwestern South America.",
        tier3_clue: "Target telemetry: latitude 0.0 degrees, longitude 78.5 degrees West."
      },
      %Waypoint{
        id: "wp-reykjavik",
        name: "Mid-Atlantic Rift, Thingvellir",
        region: "Subarctic North Atlantic",
        coord: Coord.new(64.2559, -21.1295),
        tier1_clue:
          "Navigate northward to an island where the North American and Eurasian tectonic plates pull apart above the sea.",
        tier2_clue:
          "Situated just south of the Arctic Circle in southwestern Iceland along a geothermal rift valley.",
        tier3_clue: "Target telemetry: latitude 64.3 degrees North, longitude 21.1 degrees West."
      },
      %Waypoint{
        id: "wp-suez",
        name: "Isthmus of Suez",
        region: "Northeast Africa and Sinai",
        coord: Coord.new(30.5852, 32.2654),
        tier1_clue:
          "Cross to the narrow land bridge and artificial maritime corridor linking the Mediterranean Sea with the Red Sea.",
        tier2_clue:
          "Separates the African continent from the Sinai Peninsula along an sea-level canal.",
        tier3_clue: "Target telemetry: latitude 30.6 degrees North, longitude 32.3 degrees East."
      },
      %Waypoint{
        id: "wp-singapore",
        name: "Strait of Singapore",
        region: "Maritime Southeast Asia",
        coord: Coord.new(1.2903, 103.8519),
        tier1_clue:
          "Sail east to the equatorial choke point at the southern tip of the Malay Peninsula connecting the Indian and Pacific oceans.",
        tier2_clue:
          "An island city-state positioned one degree north of the Equator between the Strait of Malacca and the South China Sea.",
        tier3_clue: "Target telemetry: latitude 1.3 degrees North, longitude 103.9 degrees East."
      },
      %Waypoint{
        id: "wp-ushuaia",
        name: "Beagle Channel, Tierra del Fuego",
        region: "Subantarctic South America",
        coord: Coord.new(-54.8019, -68.3030),
        tier1_clue:
          "Conclude the expedition at the southernmost fjord harbor of the Americas facing the Drake Passage.",
        tier2_clue:
          "Located on the southern shore of Isla Grande de Tierra del Fuego near Cape Horn.",
        tier3_clue: "Target telemetry: latitude 54.8 degrees South, longitude 68.3 degrees West."
      }
    ]
  end

  defp ring_from_pairs(pairs) do
    Enum.map(pairs, fn {lat, lon} -> Coord.new(lat, lon) end)
  end
end

