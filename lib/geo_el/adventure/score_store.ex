defmodule GeoEl.Adventure.ScoreStore do
  @moduledoc """
  Supervised GenServer managing persistent storage of explorer names and expedition scores
  backed by a durable JSON file on disk (`priv/data/leaderboard.json`).
  """

  use GenServer

  alias GeoEl.Adventure.BISE
  alias GeoEl.Adventure.SessionServer

  @max_entries 50

  @type score_entry :: %{
          id: String.t(),
          player_name: String.t(),
          score: non_neg_integer(),
          waypoints_completed: non_neg_integer(),
          fuel_remaining: float(),
          recorded_at: String.t()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec list_scores(GenServer.server()) :: [score_entry()]
  def list_scores(server \\ __MODULE__) do
    GenServer.call(server, :list_scores)
  end

  @spec record_score(
          String.t(),
          number(),
          non_neg_integer(),
          number(),
          GenServer.server()
        ) :: {:ok, score_entry(), [score_entry()]}
  def record_score(
        player_name,
        score,
        waypoints_completed \\ 0,
        fuel_remaining \\ 100.0,
        server \\ __MODULE__
      ) do
    GenServer.call(
      server,
      {:record_score, player_name, score, waypoints_completed, fuel_remaining}
    )
  end

  @spec clear_scores(GenServer.server()) :: :ok
  def clear_scores(server \\ __MODULE__) do
    GenServer.call(server, :clear_scores)
  end

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :storage_path, default_storage_path())
    entries = load_from_disk(path)
    {:ok, %{storage_path: path, entries: entries}}
  end

  @impl true
  def handle_call(:list_scores, _from, state) do
    {:reply, state.entries, state}
  end

  @impl true
  def handle_call(
        {:record_score, raw_name, raw_score, waypoints_completed, fuel_remaining},
        _from,
        state
      ) do
    sanitized_name = BISE.sanitize_player_name(raw_name)
    safe_score = max(0, round(raw_score * 1.0))
    safe_waypoints = max(0, round(waypoints_completed * 1.0))
    safe_fuel = Float.round(max(0.0, min(100.0, fuel_remaining * 1.0)), 1)

    entry = %{
      id: "score-" <> Integer.to_string(:erlang.unique_integer([:positive])),
      player_name: sanitized_name,
      score: safe_score,
      waypoints_completed: safe_waypoints,
      fuel_remaining: safe_fuel,
      recorded_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }

    updated_entries =
      [entry | state.entries]
      |> sort_and_trim()

    persist_to_disk(state.storage_path, updated_entries)

    _ =
      Phoenix.PubSub.broadcast(
        GeoEl.PubSub,
        SessionServer.pubsub_topic(),
        {:leaderboard_updated, updated_entries}
      )

    {:reply, {:ok, entry, updated_entries}, %{state | entries: updated_entries}}
  end

  @impl true
  def handle_call(:clear_scores, _from, state) do
    persist_to_disk(state.storage_path, [])
    {:reply, :ok, %{state | entries: []}}
  end

  defp default_storage_path do
    Application.get_env(
      :geo_el,
      :score_store_path,
      Path.expand("priv/data/leaderboard.json", File.cwd!())
    )
  end

  defp load_from_disk(path) do
    case File.read(path) do
      {:ok, raw} ->
        case Jason.decode(raw) do
          {:ok, list} when is_list(list) ->
            list
            |> Enum.map(&normalize_decoded_entry/1)
            |> Enum.reject(&is_nil/1)
            |> sort_and_trim()

          _ ->
            []
        end

      {:error, _} ->
        persist_to_disk(path, [])
        []
    end
  end

  defp normalize_decoded_entry(map) when is_map(map) do
    %{
      id: to_string(Map.get(map, "id") || Map.get(map, :id) || "score-0"),
      player_name:
        BISE.sanitize_player_name(Map.get(map, "player_name") || Map.get(map, :player_name)),
      score: max(0, round((Map.get(map, "score") || Map.get(map, :score) || 0) * 1.0)),
      waypoints_completed:
        max(
          0,
          round(
            (Map.get(map, "waypoints_completed") ||
               Map.get(map, :waypoints_completed) || 0) * 1.0
          )
        ),
      fuel_remaining:
        Float.round(
          (Map.get(map, "fuel_remaining") || Map.get(map, :fuel_remaining) || 0.0) * 1.0,
          1
        ),
      recorded_at:
        to_string(
          Map.get(map, "recorded_at") || Map.get(map, :recorded_at) ||
            "2026-01-01T00:00:00Z"
        )
    }
  rescue
    _ -> nil
  end

  defp normalize_decoded_entry(_), do: nil

  defp sort_and_trim(entries) do
    entries
    |> Enum.sort_by(fn entry -> {entry.score, entry.recorded_at} end, :desc)
    |> Enum.take(@max_entries)
  end

  defp persist_to_disk(path, entries) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
    json = Jason.encode!(entries, pretty: true)
    File.write!(path, json <> "\n")
  end
end
