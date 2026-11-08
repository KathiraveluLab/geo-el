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
    end
  end
end
