defmodule GeoEl.Adventure.SessionState do
  @moduledoc """
  Holds the state of an isolated explorer expedition session.
  """

  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Waypoint

  @enforce_keys [
    :session_id,
    :camera,
    :radius,
    :waypoints,
    :current_index,
    :clue_tier,
    :fuel,
    :total_score,
    :scores,
    :residuals,
    :skewness_gamma,
    :completed_legs,
    :status
  ]
  defstruct [
    :session_id,
    :player_name,
    :camera,
    :radius,
    :waypoints,
    :current_index,
    :clue_tier,
    :fuel,
    :total_score,
    :scores,
    :residuals,
    :skewness_gamma,
    :completed_legs,
    :last_guess,
    :status
  ]

  @type leg_entry :: %{
          id: String.t(),
          waypoint_name: String.t(),
          region: String.t(),
          guessed_coord: Coord.t(),
          target_coord: Coord.t(),
          distance_km: float(),
          proficiency_score: float(),
          points_awarded: non_neg_integer(),
          arc_coords: [Coord.t()]
        }

  @type t :: %__MODULE__{
          session_id: String.t(),
          player_name: String.t() | nil,
          camera: Coord.t(),
          radius: float(),
          waypoints: [Waypoint.t()],
          current_index: non_neg_integer(),
          clue_tier: 1 | 2 | 3,
          fuel: float(),
          total_score: non_neg_integer(),
          scores: [float()],
          residuals: [float()],
          skewness_gamma: float(),
          completed_legs: [leg_entry()],
          last_guess: leg_entry() | nil,
          status: :in_progress | :completed | :out_of_fuel
        }
end
