defmodule GeoEl.Adventure.SessionServerTest do
  use ExUnit.Case, async: true

  alias GeoEl.Adventure.BISE
  alias GeoEl.Adventure.ScoreStore
  alias GeoEl.Adventure.SessionServer

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

      first_wp = hd(initial_state.waypoints)

      {:ok, after_guess_state, leg_entry} =
        SessionServer.submit_coord_guess(pid, first_wp.coord)

      _ = :sys.get_state(pid)
      assert after_guess_state.current_index == 1
      assert leg_entry.distance_km < 1.0
      assert after_guess_state.total_score > 0

      reset_state = SessionServer.reset_expedition(pid)
      _ = :sys.get_state(pid)
      initial_ids = MapSet.new(Enum.map(initial_state.waypoints, & &1.id))
      reset_ids = MapSet.new(Enum.map(reset_state.waypoints, & &1.id))
      assert MapSet.size(initial_ids) == 6
      assert MapSet.size(reset_ids) == 6
      assert MapSet.disjoint?(initial_ids, reset_ids)

      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "persists sanitized player names and scores to disk via ScoreStore" do
      temp_path =
        Path.join(
          System.tmp_dir!(),
          "geo_el_scores_#{System.unique_integer([:positive])}.json"
        )

      store_name = :"score_store_#{System.unique_integer([:positive])}"

      store_pid =
        start_supervised!({ScoreStore, [name: store_name, storage_path: temp_path]})

      assert BISE.sanitize_player_name("   ") == "Anonymous Explorer"
      assert BISE.sanitize_player_name("  Explorer\nOne  ") == "Explorer One"

      {:ok, entry1, _all} = ScoreStore.record_score("Alice", 2400, 3, 92.5, store_pid)
      {:ok, entry2, all} = ScoreStore.record_score("Bob", 4100, 5, 85.0, store_pid)

      assert entry1.player_name == "Alice"
      assert entry2.player_name == "Bob"
      assert Enum.map(all, & &1.player_name) == ["Bob", "Alice"]
      assert File.exists?(temp_path)

      reloaded_name = :"score_store_reloaded_#{System.unique_integer([:positive])}"

      reloaded_pid =
        start_supervised!(
          {ScoreStore, [name: reloaded_name, storage_path: temp_path]},
          id: :reloaded_store
        )

      reloaded_scores = ScoreStore.list_scores(reloaded_pid)

      assert Enum.map(reloaded_scores, &{&1.player_name, &1.score}) == [
               {"Bob", 4100},
               {"Alice", 2400}
             ]

      File.rm(temp_path)
    end
  end
end
