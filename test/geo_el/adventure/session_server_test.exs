defmodule GeoEl.Adventure.SessionServerTest do
  use ExUnit.Case, async: true

  alias GeoEl.Adventure.SessionServer
  alias GeoEl.Globe.Coord

  describe "supervised SessionServer lifecycle and state transitions" do
    test "isolates session state, clamps rotation deltas, and records waypoint guesses" do
      session_id = "test-session-#{System.unique_integer([:positive])}"

      pid =
        start_supervised!(
          {SessionServer, [session_id: session_id, name: SessionServer.via_tuple(session_id)]}
        )

      initial_state = SessionServer.get_state(pid)
      assert initial_state.session_id == session_id
      assert initial_state.current_index == 0

      rotated_state = SessionServer.rotate_camera(pid, 200.0, -200.0)
      _ = :sys.get_state(pid)
      assert_in_delta rotated_state.camera.lat, 65.0, 1.0e-4
      assert_in_delta rotated_state.camera.lon, -45.0, 1.0e-4

      hinted_state = SessionServer.request_hint(pid)
      _ = :sys.get_state(pid)
      assert hinted_state.clue_tier == 2
      assert hinted_state.fuel < initial_state.fuel

      {:ok, after_guess_state, leg_entry} =
        SessionServer.submit_coord_guess(pid, Coord.new(51.4769, 0.0005))

      _ = :sys.get_state(pid)
      assert after_guess_state.current_index == 1
      assert leg_entry.distance_km < 1.0
      assert after_guess_state.total_score > 0

      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end
end
