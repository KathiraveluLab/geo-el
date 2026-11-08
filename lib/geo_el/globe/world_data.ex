defmodule GeoEl.Globe.WorldData do
  @moduledoc """
  Manages static cartographic continent contours and expedition waypoints in shared constant storage.
  """

  alias GeoEl.Adventure.BISE
  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Waypoint

  @continents_key {__MODULE__, :continents}
  @waypoints_key {__MODULE__, :waypoints}
  @default_expedition_size 6

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

  @doc """
  Randomly samples `count` unique waypoints without replacement from the global waypoint catalog.
  When `exclude_ids` is provided, prioritizes unseen waypoints first so consecutive expeditions
  do not repeat questions.
  """
  @spec sample_expedition_waypoints(pos_integer(), [String.t()]) :: [Waypoint.t()]
  def sample_expedition_waypoints(count \\ @default_expedition_size, exclude_ids \\ [])
      when is_integer(count) and count > 0 and is_list(exclude_ids) do
    all_waypoints = waypoints()
    excluded_set = MapSet.new(exclude_ids)

    {fresh, seen} =
      Enum.split_with(all_waypoints, fn wp -> not MapSet.member?(excluded_set, wp.id) end)

    (Enum.shuffle(fresh) ++ Enum.shuffle(seen))
    |> Enum.take(count)
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
      },
      %Waypoint{
        id: "wp-gibraltar",
        name: "Strait of Gibraltar",
        region: "Western Mediterranean Gateway",
        coord: Coord.new(35.9720, -5.4958),
        tier1_clue:
          "Locate the narrow tectonic sill where Atlantic surface waters pour eastward into a nearly enclosed basin.",
        tier2_clue: "Flanked by the southern tip of the Iberian Peninsula and northern Morocco.",
        tier3_clue: "Target telemetry: latitude 36.0 degrees North, longitude 5.5 degrees West."
      },
      %Waypoint{
        id: "wp-kilimanjaro",
        name: "Uhuru Peak, Mount Kilimanjaro",
        region: "East African Rift Highlands",
        coord: Coord.new(-3.0674, 37.3556),
        tier1_clue:
          "Identify the freestanding dormant stratovolcano rising nearly six kilometers above equatorial savannas.",
        tier2_clue: "Positioned along the northern border of Tanzania just south of the Equator.",
        tier3_clue: "Target telemetry: latitude 3.1 degrees South, longitude 37.4 degrees East."
      },
      %Waypoint{
        id: "wp-panama",
        name: "Culebra Cut, Isthmus of Panama",
        region: "Central American Land Bridge",
        coord: Coord.new(9.0800, -79.6800),
        tier1_clue:
          "Pinpoint the excavated continental divide linking the Caribbean Sea to the Gulf of Panama.",
        tier2_clue:
          "Cuts across the narrowest S-shaped isthmus connecting North and South America.",
        tier3_clue: "Target telemetry: latitude 9.1 degrees North, longitude 79.7 degrees West."
      },
      %Waypoint{
        id: "wp-baikal",
        name: "Olkhon Island, Lake Baikal",
        region: "Continental Siberia",
        coord: Coord.new(53.1494, 107.3728),
        tier1_clue:
          "Search the interior of northern Eurasia for the world's deepest continental rift lake.",
        tier2_clue:
          "Crescent-shaped freshwater basin in southern Siberia north of the Mongolian steppe.",
        tier3_clue: "Target telemetry: latitude 53.1 degrees North, longitude 107.4 degrees East."
      },
      %Waypoint{
        id: "wp-uluru",
        name: "Uluru Monolith, Amadeus Basin",
        region: "Central Australian Outback",
        coord: Coord.new(-25.3444, 131.0369),
        tier1_clue:
          "Navigate to the isolated arkose sandstone inselberg rising from an arid red desert plain near the Tropic of Capricorn.",
        tier2_clue:
          "Situated in the southern Northern Territory near the centre of the Australian continent.",
        tier3_clue: "Target telemetry: latitude 25.3 degrees South, longitude 131.0 degrees East."
      },
      %Waypoint{
        id: "wp-everest",
        name: "Khumbu Massif, Mount Everest",
        region: "Central Himalayas",
        coord: Coord.new(27.9881, 86.9250),
        tier1_clue:
          "Ascend to the highest continental collision crest where the Indian plate thrusts beneath the Tibetan Plateau.",
        tier2_clue:
          "Straddles the border between Nepal and Tibet along the Mahalangur Himal range.",
        tier3_clue: "Target telemetry: latitude 28.0 degrees North, longitude 86.9 degrees East."
      },
      %Waypoint{
        id: "wp-victoria-falls",
        name: "Batoka Gorge, Victoria Falls",
        region: "Zambezi River Basin",
        coord: Coord.new(-17.9243, 25.8572),
        tier1_clue:
          "Track a major southern African river where its entire width plunges into a transverse basaltic chasm.",
        tier2_clue: "Located along the Zambezi River on the border between Zambia and Zimbabwe.",
        tier3_clue: "Target telemetry: latitude 17.9 degrees South, longitude 25.9 degrees East."
      },
      %Waypoint{
        id: "wp-galapagos",
        name: "Isabela Island, Galapagos",
        region: "Eastern Equatorial Pacific",
        coord: Coord.new(-0.0200, -91.3500),
        tier1_clue:
          "Locate the oceanic hotspot archipelago sitting directly on the Equator west of South America.",
        tier2_clue:
          "Lies approximately 1,000 kilometers west of mainland Ecuador in the Pacific Ocean.",
        tier3_clue: "Target telemetry: latitude 0.0 degrees, longitude 91.4 degrees West."
      },
      %Waypoint{
        id: "wp-svalbard",
        name: "Spitsbergen Fjord, Svalbard",
        region: "High Arctic Ocean",
        coord: Coord.new(78.2232, 15.6267),
        tier1_clue:
          "Head deep into the High Arctic to a glaciated archipelago midway between northern Norway and the North Pole.",
        tier2_clue: "Borders the Greenland and Barents seas well north of the Arctic Circle.",
        tier3_clue: "Target telemetry: latitude 78.2 degrees North, longitude 15.6 degrees East."
      },
      %Waypoint{
        id: "wp-dead-sea",
        name: "Dead Sea Transform, Jordan Rift",
        region: "Levantine Rift Corridor",
        coord: Coord.new(31.5590, 35.4732),
        tier1_clue:
          "Descend to the hypersaline endorheic lake occupying the lowest exposed land elevation on Earth.",
        tier2_clue: "Positioned in the Jordan Rift Valley east of the Mediterranean coast.",
        tier3_clue: "Target telemetry: latitude 31.6 degrees North, longitude 35.5 degrees East."
      },
      %Waypoint{
        id: "wp-titicaca",
        name: "Isla del Sol, Lake Titicaca",
        region: "Andean Altiplano",
        coord: Coord.new(-15.9254, -69.3354),
        tier1_clue:
          "Find the high-elevation navigable alpine lake nestled within the central Andean Altiplano.",
        tier2_clue: "Sits at 3,812 meters elevation on the border between Peru and Bolivia.",
        tier3_clue: "Target telemetry: latitude 15.9 degrees South, longitude 69.3 degrees West."
      },
      %Waypoint{
        id: "wp-hormuz",
        name: "Strait of Hormuz",
        region: "Persian Gulf Entrance",
        coord: Coord.new(26.5667, 56.2500),
        tier1_clue:
          "Chart the curved maritime choke point separating the Persian Gulf from the Gulf of Oman.",
        tier2_clue:
          "Flanked by the Musandam Peninsula to the south and the Iranian coast to the north.",
        tier3_clue: "Target telemetry: latitude 26.6 degrees North, longitude 56.3 degrees East."
      },
      %Waypoint{
        id: "wp-good-hope",
        name: "Cape of Good Hope",
        region: "Southern African Margin",
        coord: Coord.new(-34.3568, 18.4740),
        tier1_clue:
          "Round the rocky headland near the southwestern extremity of the African continent where Atlantic swells meet warm currents.",
        tier2_clue: "Forms the southern tip of the Cape Peninsula in South Africa.",
        tier3_clue: "Target telemetry: latitude 34.4 degrees South, longitude 18.5 degrees East."
      },
      %Waypoint{
        id: "wp-bering",
        name: "Diomede Islands, Bering Strait",
        region: "Subarctic Pacific Gateway",
        coord: Coord.new(65.7783, -168.9519),
        tier1_clue:
          "Navigate to the shallow high-latitude strait separating the easternmost cape of Asia from the westernmost point of North America.",
        tier2_clue:
          "Connects the Bering Sea with the Chukchi Sea along the International Date Line.",
        tier3_clue: "Target telemetry: latitude 65.8 degrees North, longitude 169.0 degrees West."
      },
      %Waypoint{
        id: "wp-madagascar",
        name: "Tsingy de Bemaraha, Madagascar",
        region: "Western Indian Ocean",
        coord: Coord.new(-18.6667, 44.7500),
        tier1_clue:
          "Cross the Mozambique Channel to the karst limestone pinnacles on the fourth-largest island in the world.",
        tier2_clue: "Located near the western coast of Madagascar in the Indian Ocean.",
        tier3_clue: "Target telemetry: latitude 18.7 degrees South, longitude 44.8 degrees East."
      },
      %Waypoint{
        id: "wp-denali",
        name: "Alaska Range, Denali",
        region: "Subarctic North America",
        coord: Coord.new(63.0692, -151.0070),
        tier1_clue:
          "Locate the granite batholith summit that stands as the highest mountain peak in North America.",
        tier2_clue: "Rises above interior Alaska north of Cook Inlet.",
        tier3_clue: "Target telemetry: latitude 63.1 degrees North, longitude 151.0 degrees West."
      },
      %Waypoint{
        id: "wp-atacama",
        name: "Salar de Atacama",
        region: "Hyperarid Andean Plateau",
        coord: Coord.new(-23.5000, -68.2500),
        tier1_clue:
          "Identify the rain-shadowed salt flat trapped between the Pacific Coastal Range and the main cordillera of the Andes.",
        tier2_clue: "Situated in northern Chile along the Tropic of Capricorn.",
        tier3_clue: "Target telemetry: latitude 23.5 degrees South, longitude 68.3 degrees West."
      },
      %Waypoint{
        id: "wp-milford",
        name: "Milford Sound, Fiordland",
        region: "Southern Alps, New Zealand",
        coord: Coord.new(-44.6414, 167.8974),
        tier1_clue:
          "Sail into the glacially carved fjord on the southwestern coast of a temperate South Pacific archipelago.",
        tier2_clue:
          "Located on the west coast of New Zealand's South Island facing the Tasman Sea.",
        tier3_clue: "Target telemetry: latitude 44.6 degrees South, longitude 167.9 degrees East."
      }
    ]
  end

  defp ring_from_pairs(pairs) do
    Enum.map(pairs, fn {lat, lon} -> Coord.new(lat, lon) end)
  end
end
