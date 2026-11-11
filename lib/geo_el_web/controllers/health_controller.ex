defmodule GeoElWeb.HealthController do
  @moduledoc """
  Lightweight health-check endpoint for Render readiness and liveness probes.
  """

  use GeoElWeb, :controller

  alias GeoEl.Globe.WorldData

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    json(conn, %{
      status: "ok",
      waypoints: length(WorldData.waypoints())
    })
  end
end
