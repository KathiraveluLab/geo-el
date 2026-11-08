defmodule GeoEl.Adventure.SessionServer do
  @moduledoc """
  Supervised GenServer worker managing an explorer's globe adventure session,
  applying BISE input verification and SkewPNN/A2 difficulty calibration.
  """

  use GenServer

  alias GeoEl.Adventure.BISE
  alias GeoEl.Adventure.Calibration
  alias GeoEl.Adventure.SessionState
  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Math
  alias GeoEl.Globe.Projection
  alias GeoEl.Globe.WorldData

  @default_radius 220.0
  @initial_fuel 100.0
  @pubsub_topic "expedition:global"

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    name = Keyword.get(opts, :name, via_tuple(session_id))
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec via_tuple(String.t()) :: {:via, Registry, {GeoEl.Adventure.Registry, String.t()}}
  def via_tuple(session_id) when is_binary(session_id) do
    {:via, Registry, {GeoEl.Adventure.Registry, session_id}}
  end

  @spec get_state(GenServer.server()) :: SessionState.t()
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  @spec rotate_camera(GenServer.server(), number(), number()) :: SessionState.t()
  def rotate_camera(server, dlat, dlon) do
    GenServer.call(server, {:rotate_camera, dlat, dlon})
  end

  @spec request_hint(GenServer.server()) :: SessionState.t()
  def request_hint(server) do
    GenServer.call(server, :request_hint)
  end

  @spec submit_viewport_click(GenServer.server(), number(), number()) ::
          {:ok, SessionState.t(), SessionState.leg_entry() | nil}
  def submit_viewport_click(server, offset_x, offset_y) do
    GenServer.call(server, {:submit_viewport_click, offset_x, offset_y})
  end

  @spec submit_coord_guess(GenServer.server(), Coord.t()) ::
          {:ok, SessionState.t(), SessionState.leg_entry() | nil}
  def submit_coord_guess(server, %Coord{} = guessed_coord) do
    GenServer.call(server, {:submit_coord_guess, guessed_coord})
  end

  @spec reset_expedition(GenServer.server()) :: SessionState.t()
  def reset_expedition(server) do
    GenServer.call(server, :reset_expedition)
  end

  @spec pubsub_topic() :: String.t()
  def pubsub_topic, do: @pubsub_topic

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    radius = Keyword.get(opts, :radius, @default_radius) * 1.0
    {:ok, build_initial_state(session_id, radius)}
  end

  @impl true
  def handle_call(:get_state, _from, %SessionState{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:rotate_camera, dlat, dlon}, _from, %SessionState{} = state) do
    {safe_dlat, safe_dlon} = BISE.sanitize_rotation_delta(dlat, dlon)

    updated_camera =
      Coord.new(
        state.camera.lat + safe_dlat,
        state.camera.lon + safe_dlon
      )

    next_state = %{state | camera: updated_camera}
    {:reply, next_state, next_state}
  end

  @impl true
  def handle_call(:request_hint, _from, %SessionState{} = state) do
    next_tier =
      cond do
        state.clue_tier == 1 -> 2
        state.clue_tier == 2 -> 3
        true -> 3
      end

    fuel_cost =
      if next_tier > state.clue_tier do
        4.0
      else
        0.0
      end

    next_fuel = max(0.0, Float.round(state.fuel - fuel_cost, 2))
    next_state = %{state | clue_tier: next_tier, fuel: next_fuel}
    {:reply, next_state, next_state}
  end

  @impl true
  def handle_call({:submit_viewport_click, offset_x, offset_y}, _from, %SessionState{} = state) do
    {:ok, guessed_coord, cos_c} =
      Projection.inverse(offset_x, offset_y, state.camera, state.radius)

    {next_state, leg_entry} = evaluate_guess(state, guessed_coord, cos_c)
    {:reply, {:ok, next_state, leg_entry}, next_state}
  end

  @impl true
  def handle_call({:submit_coord_guess, %Coord{} = guessed_coord}, _from, %SessionState{} = state) do
    cos_c = max(0.35, Math.cos_central_angle(guessed_coord, state.camera))
    {next_state, leg_entry} = evaluate_guess(state, guessed_coord, cos_c)
    {:reply, {:ok, next_state, leg_entry}, next_state}
  end

  @impl true
  def handle_call(:reset_expedition, _from, %SessionState{} = state) do
    reset_state = build_initial_state(state.session_id, state.radius)
    {:reply, reset_state, reset_state}
  end

  defp build_initial_state(session_id, radius) do
    %SessionState{
      session_id: session_id,
      camera: Coord.new(20.0, 0.0),
      radius: radius,
      waypoints: WorldData.waypoints(),
      current_index: 0,
      clue_tier: 1,
      fuel: @initial_fuel,
      total_score: 0,
      scores: [],
      residuals: [],
      skewness_gamma: 0.0,
      completed_legs: [],
      last_guess: nil,
      status: :in_progress
    }
  end

  defp evaluate_guess(%SessionState{status: status} = state, _coord, _cos_c)
       when status != :in_progress do
    {state, nil}
  end

  defp evaluate_guess(%SessionState{} = state, %Coord{} = guessed_coord, cos_c) do
    target_wp = Enum.at(state.waypoints, state.current_index)

    if is_nil(target_wp) do
      {%{state | status: :completed}, nil}
    else
      distance_km = Float.round(Math.haversine_distance(guessed_coord, target_wp.coord), 2)
      updated_residuals = state.residuals ++ [distance_km]
      updated_gamma = Calibration.estimate_skewness(updated_residuals)

      proficiency_score =
        distance_km
        |> Calibration.compute_score(updated_gamma, cos_c)
        |> Float.round(4)

      updated_scores = state.scores ++ [proficiency_score]
      next_recommended_tier = Calibration.recommend_clue_tier(proficiency_score)

      tier_multiplier =
        case state.clue_tier do
          1 -> 1.0
          2 -> 0.85
          3 -> 0.70
        end

      points_awarded = round(1000.0 * proficiency_score * tier_multiplier)
      fuel_burn = Float.round(min(30.0, distance_km / 450.0), 2)
      remaining_fuel = max(0.0, Float.round(state.fuel - fuel_burn, 2))

      origin_coord =
        case state.last_guess do
          nil -> Coord.new(0.0, 0.0)
          prev_leg -> prev_leg.target_coord
        end

      arc_coords = Math.interpolate_arc(origin_coord, target_wp.coord, 24)

      leg_entry = %{
        id: "leg-#{state.session_id}-#{state.current_index + 1}",
        waypoint_name: target_wp.name,
        region: target_wp.region,
        guessed_coord: guessed_coord,
        target_coord: target_wp.coord,
        distance_km: distance_km,
        proficiency_score: proficiency_score,
        points_awarded: points_awarded,
        arc_coords: arc_coords
      }

      next_index = state.current_index + 1
      total_waypoints = length(state.waypoints)

      next_status =
        cond do
          next_index >= total_waypoints -> :completed
          remaining_fuel <= 0.0 -> :out_of_fuel
          true -> :in_progress
        end

      next_state = %SessionState{
        state
        | camera: target_wp.coord,
          current_index: next_index,
          clue_tier: next_recommended_tier,
          fuel: remaining_fuel,
          total_score: state.total_score + points_awarded,
          scores: updated_scores,
          residuals: updated_residuals,
          skewness_gamma: updated_gamma,
          completed_legs: state.completed_legs ++ [leg_entry],
          last_guess: leg_entry,
          status: next_status
      }

      _ =
        Phoenix.PubSub.broadcast(
          GeoEl.PubSub,
          @pubsub_topic,
          {:expedition_leg_completed, state.session_id, leg_entry}
        )

      {next_state, leg_entry}
    end
  end
end

