defmodule GeoElWeb.GlobeLiveTest do
  use GeoElWeb.ConnCase, async: true

  describe "GlobeLive interactive orthographic viewport" do
    test "renders light-themed SVG globe, clue panel, and handles rotation and coordinate submission",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#how-to-play-banner")
      assert has_element?(view, "#globe-viewport")
      assert has_element?(view, "#globe-ocean-sphere")
      assert has_element?(view, "#globe-legend")
      assert has_element?(view, "#expedition-hud")
      assert has_element?(view, "#active-clue-panel")
      assert has_element?(view, "#waypoint-guess-form")
      assert has_element?(view, "#calibration-telemetry-card")
      refute has_element?(view, "#last-turn-feedback")

      view
      |> element("#rotate-east-btn")
      |> render_click()

      assert has_element?(view, "#camera-telemetry")

      view
      |> element("#request-hint-btn")
      |> render_click()

      assert has_element?(view, "#tier2-clue-text")

      view
      |> form("#waypoint-guess-form", guess: %{lat: "51.4769", lon: "0.0005"})
      |> render_submit()

      assert has_element?(view, "#last-turn-feedback")
      assert has_element?(view, "#expedition-log")
      refute has_element?(view, "#expedition-log-empty")

      assert has_element?(view, "#save-score-form")
      assert has_element?(view, "#leaderboard-card")

      view
      |> form("#save-score-form", player: %{player_name: "Captain Nemo"})
      |> render_submit()

      assert has_element?(view, "#score-saved-notice")
      assert has_element?(view, "#leaderboard-list")
      assert render(view) =~ "Captain Nemo"
    end

    test "serves static CSS and LiveView JS assets with HTTP 200", %{conn: conn} do
      assert get(conn, "/assets/app.css").status == 200
      assert get(conn, "/assets/app.js").status == 200
      assert get(conn, "/assets/vendor/phoenix.min.js").status == 200
      assert get(conn, "/assets/vendor/phoenix_live_view.min.js").status == 200
    end

    test "responds HTTP 200 JSON from /healthz readiness endpoint", %{conn: conn} do
      conn = get(conn, "/healthz")
      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "ok"
      assert is_integer(body["waypoints"]) and body["waypoints"] > 0
    end
  end
end
