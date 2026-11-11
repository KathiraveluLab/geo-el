defmodule GeoEl.Globe.WorldData do
  @moduledoc """
  Manages static cartographic continent contours and teacher-editable YAML expedition
  questions stored in shared constant memory (`:persistent_term`).
  """

  require Logger

  alias GeoEl.Adventure.BISE
  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Waypoint
  alias GeoEl.Globe.YamlParser

  @continents_key {__MODULE__, :continents}
  @waypoints_key {__MODULE__, :waypoints}
  @expedition_size_key {__MODULE__, :expedition_size}
  @questions_path_key {__MODULE__, :questions_path}
  @questions_mtime_key {__MODULE__, :questions_mtime}
  @default_expedition_size 6

  @doc """
  Returns the resolved filesystem path to the active YAML question bank (`priv/data/questions.yaml`).
  """
  @spec questions_path() :: String.t()
  def questions_path do
    case Application.get_env(:geo_el, :questions_path) do
      path when is_binary(path) and path != "" ->
        path

      _ ->
        cwd_path = Path.expand("priv/data/questions.yaml", File.cwd!())

        if File.exists?(cwd_path) do
          cwd_path
        else
          Application.app_dir(:geo_el, "priv/data/questions.yaml")
        end
    end
  end

  @doc """
  Validates static continent contours and loads waypoint questions from the YAML file
  into `:persistent_term`.
  """
  @spec load_into_persistent_term!(keyword()) :: :ok
  def load_into_persistent_term!(opts \\ []) do
    continents = build_continents()

    Enum.each(continents, fn %{name: name, coords: ring} ->
      if not BISE.valid_closed_ring?(ring) do
        raise ArgumentError, "Invalid closed cartographic ring for #{name}"
      end
    end)

    :persistent_term.put(@continents_key, continents)
    path = Keyword.get(opts, :questions_path, questions_path())
    reload_questions!(path)
  end

  @doc """
  Reloads waypoint questions and expedition configuration from the specified YAML path
  (or the default `questions_path/0`) and updates `:persistent_term`.
  """
  @spec reload_questions!(String.t() | nil) :: :ok
  def reload_questions!(path \\ nil) do
    resolved_path = path || questions_path()
    {waypoints, size, mtime} = load_questions_from_file!(resolved_path)

    :persistent_term.put(@waypoints_key, waypoints)
    :persistent_term.put(@expedition_size_key, size)
    :persistent_term.put(@questions_path_key, resolved_path)
    :persistent_term.put(@questions_mtime_key, mtime)
    :ok
  end

  @doc """
  Parses and validates a YAML question bank file, returning `{waypoints, expedition_size, mtime}`.
  Raises `ArgumentError` with line or entry details on malformed YAML or out-of-bounds coordinates.
  """
  @spec load_questions_from_file!(String.t()) :: {[Waypoint.t()], pos_integer(), tuple() | nil}
  def load_questions_from_file!(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} ->
        mtime =
          case File.stat(path) do
            {:ok, %File.Stat{mtime: m}} -> m
            _ -> nil
          end

        {waypoints, size} = parse_questions_yaml!(content, path)
        {waypoints, size, mtime}

      {:error, reason} ->
        raise ArgumentError,
              "Unable to read questions YAML file at #{path}: #{:file.format_error(reason)}"
    end
  end

  @doc """
  Parses and validates raw YAML text into `{waypoints, expedition_size}`.
  """
  @spec parse_questions_yaml!(String.t(), String.t()) :: {[Waypoint.t()], pos_integer()}
  def parse_questions_yaml!(content, source_label \\ "questions.yaml") when is_binary(content) do
    parsed =
      case YamlParser.parse(content) do
        {:ok, data} ->
          data

        {:error, reason} ->
          raise ArgumentError, "Invalid YAML syntax in #{source_label}: #{reason}"
      end

    {raw_items, raw_size} = extract_catalog(parsed, source_label)

    if raw_items == [] do
      raise ArgumentError, "Question bank in #{source_label} must contain at least one question."
    end

    {waypoints, _seen_ids} =
      raw_items
      |> Enum.with_index(1)
      |> Enum.map_reduce(MapSet.new(), fn {entry, idx}, seen_ids ->
        waypoint = build_validated_waypoint!(entry, idx, source_label)

        if MapSet.member?(seen_ids, waypoint.id) do
          raise ArgumentError,
                "Duplicate question id '#{waypoint.id}' at entry ##{idx} in #{source_label}."
        end

        {waypoint, MapSet.put(seen_ids, waypoint.id)}
      end)

    expedition_size = normalize_expedition_size(raw_size, length(waypoints), source_label)
    {waypoints, expedition_size}
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

      _data ->
        maybe_reload_if_modified()
        :persistent_term.get(@waypoints_key)
    end
  end

  @doc """
  Returns the configured number of waypoints drawn per expedition (capped by catalog size).
  """
  @spec expedition_size() :: pos_integer()
  def expedition_size do
    _ = waypoints()
    :persistent_term.get(@expedition_size_key, @default_expedition_size)
  end

  @doc """
  Randomly samples `count` unique waypoints without replacement from the active YAML catalog.
  When `exclude_ids` is provided, prioritizes unseen waypoints first so consecutive expeditions
  do not repeat questions.
  """
  @spec sample_expedition_waypoints(pos_integer() | nil, [String.t()]) :: [Waypoint.t()]
  def sample_expedition_waypoints(count \\ nil, exclude_ids \\ [])
      when (is_nil(count) or (is_integer(count) and count > 0)) and is_list(exclude_ids) do
    all_waypoints = waypoints()
    target_count = min(count || expedition_size(), length(all_waypoints))
    excluded_set = MapSet.new(exclude_ids)

    {fresh, seen} =
      Enum.split_with(all_waypoints, fn wp -> not MapSet.member?(excluded_set, wp.id) end)

    (Enum.shuffle(fresh) ++ Enum.shuffle(seen))
    |> Enum.take(target_count)
  end

  defp maybe_reload_if_modified do
    cached_path = :persistent_term.get(@questions_path_key, nil)
    cached_mtime = :persistent_term.get(@questions_mtime_key, nil)
    current_path = questions_path()

    cond do
      is_nil(cached_path) ->
        :ok

      cached_path != current_path ->
        safe_hot_reload(current_path)

      true ->
        case File.stat(current_path) do
          {:ok, %File.Stat{mtime: mtime}} when mtime != cached_mtime ->
            safe_hot_reload(current_path)

          _ ->
            :ok
        end
    end
  end

  defp safe_hot_reload(path) do
    reload_questions!(path)
  rescue
    e in ArgumentError ->
      Logger.warning(
        "Failed to hot-reload #{path}: #{Exception.message(e)}. Keeping previously loaded questions."
      )

      :ok
  end

  defp extract_catalog(list, _source) when is_list(list), do: {list, nil}

  defp extract_catalog(map, source) when is_map(map) do
    items = Map.get(map, "questions") || Map.get(map, "waypoints")
    raw_size = Map.get(map, "expedition_size")

    if is_list(items) do
      {items, raw_size}
    else
      raise ArgumentError,
            "Expected a `questions:` list in #{source}."
    end
  end

  defp extract_catalog(_, source) do
    raise ArgumentError,
          "Expected a YAML mapping with `questions:` or a top-level list in #{source}."
  end

  defp normalize_expedition_size(nil, catalog_len, _source) do
    min(@default_expedition_size, catalog_len)
  end

  defp normalize_expedition_size(size, catalog_len, _source)
       when is_integer(size) and size > 0 do
    min(size, catalog_len)
  end

  defp normalize_expedition_size(invalid, _catalog_len, source) do
    raise ArgumentError,
          "Invalid `expedition_size` (#{inspect(invalid)}) in #{source}; expected a positive integer."
  end

  defp build_validated_waypoint!(entry, idx, source) when is_map(entry) do
    name = require_non_empty_string!(entry, ["name", "answer"], idx, "name", source)

    tier1 =
      require_non_empty_string!(entry, ["tier1_clue", "question"], idx, "tier1_clue", source)

    region = optional_string(entry, "region") || "Global Landmark"
    id = optional_string(entry, "id") || slugify_id(name, idx)

    {lat, lon} = extract_lat_lon!(entry, idx, id, source)
    coord = Coord.new(lat, lon)

    tier2 = optional_string(entry, "tier2_clue") || "Located in #{region}."
    tier3 = optional_string(entry, "tier3_clue") || format_target_telemetry(lat, lon)

    %Waypoint{
      id: id,
      name: name,
      region: region,
      coord: coord,
      tier1_clue: tier1,
      tier2_clue: tier2,
      tier3_clue: tier3
    }
  end

  defp build_validated_waypoint!(_entry, idx, source) do
    raise ArgumentError,
          "Question entry ##{idx} in #{source} must be a YAML mapping of fields."
  end

  defp extract_lat_lon!(entry, idx, id, source) do
    nested = Map.get(entry, "coord")

    raw_lat =
      cond do
        Map.has_key?(entry, "lat") -> Map.get(entry, "lat")
        is_map(nested) -> Map.get(nested, "lat")
        true -> nil
      end

    raw_lon =
      cond do
        Map.has_key?(entry, "lon") -> Map.get(entry, "lon")
        is_map(nested) -> Map.get(nested, "lon")
        true -> nil
      end

    lat = parse_coordinate_number!(raw_lat, "lat", idx, id, source)
    lon = parse_coordinate_number!(raw_lon, "lon", idx, id, source)

    if not BISE.valid_coord_bounds?(lat, lon) do
      raise ArgumentError,
            "Question ##{idx} (#{id}) in #{source}: coordinates (#{lat}, #{lon}) out of bounds; lat must be in [-90.0, 90.0] and lon in [-180.0, 180.0]."
    end

    {lat, lon}
  end

  defp parse_coordinate_number!(val, field, idx, id, source) do
    cond do
      is_float(val) ->
        val

      is_integer(val) ->
        val * 1.0

      is_binary(val) ->
        case Float.parse(String.trim(val)) do
          {num, ""} ->
            num

          _ ->
            raise ArgumentError,
                  "Question ##{idx} (#{id}) in #{source}: `#{field}` must be a number, got #{inspect(val)}."
        end

      true ->
        raise ArgumentError,
              "Question ##{idx} (#{id}) in #{source}: missing or invalid numeric `#{field}`."
    end
  end

  defp require_non_empty_string!(entry, candidate_keys, idx, canonical_name, source) do
    value =
      Enum.find_value(candidate_keys, fn key ->
        optional_string(entry, key)
      end)

    if is_nil(value) do
      raise ArgumentError,
            "Question ##{idx} in #{source}: missing required `#{canonical_name}` field."
    else
      value
    end
  end

  defp optional_string(entry, key) do
    case Map.get(entry, key) do
      nil ->
        nil

      val when is_binary(val) ->
        trimmed = String.trim(val)
        if trimmed == "", do: nil, else: trimmed

      val ->
        str = to_string(val) |> String.trim()
        if str == "", do: nil, else: str
    end
  end

  defp slugify_id(name, idx) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
      |> String.slice(0, 32)

    if slug == "", do: "wp-#{idx}", else: "wp-#{slug}-#{idx}"
  end

  defp format_target_telemetry(lat, lon) do
    ns = if lat >= 0.0, do: "North", else: "South"
    ew = if lon >= 0.0, do: "East", else: "West"
    abs_lat = Float.round(abs(lat * 1.0), 1)
    abs_lon = Float.round(abs(lon * 1.0), 1)
    "Target telemetry: latitude #{abs_lat} degrees #{ns}, longitude #{abs_lon} degrees #{ew}."
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

  defp ring_from_pairs(pairs) do
    Enum.map(pairs, fn {lat, lon} -> Coord.new(lat, lon) end)
  end
end
