defmodule GeoEl.Globe.Waypoint do
  @moduledoc """
  Represents an expedition waypoint target on the globe with progressive three-tier geographic clues.
  """

  alias GeoEl.Globe.Coord

  @enforce_keys [:id, :name, :region, :coord, :tier1_clue, :tier2_clue, :tier3_clue]
  defstruct [:id, :name, :region, :coord, :tier1_clue, :tier2_clue, :tier3_clue]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          region: String.t(),
          coord: Coord.t(),
          tier1_clue: String.t(),
          tier2_clue: String.t(),
          tier3_clue: String.t()
        }
end

