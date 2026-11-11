defmodule GeoEl.Globe.YamlParserTest do
  use ExUnit.Case, async: true

  alias GeoEl.Globe.YamlParser

  describe "YamlParser.parse/1" do
    test "parses teacher question banks with comments, quotes, colons, and floats" do
      yaml = """
      # Leading comment
      expedition_size: 4 # inline comment

      questions:
        - id: wp-custom-1
          name: "Grand Canyon, Arizona"
          region: 'Colorado Plateau'
          lat: 36.1069
          lon: -112.1129
          tier1_clue: "Steep gorge #1: carved across the Colorado Plateau."
          tier2_clue: 'Wait, isn''t this in northern Arizona?'
          tier3_clue: Target telemetry: latitude 36.1 degrees North, longitude 112.1 degrees West.
      """

      assert {:ok, parsed} = YamlParser.parse(yaml)
      assert parsed["expedition_size"] == 4
      assert [item] = parsed["questions"]
      assert item["id"] == "wp-custom-1"
      assert item["name"] == "Grand Canyon, Arizona"
      assert item["region"] == "Colorado Plateau"
      assert_in_delta item["lat"], 36.1069, 1.0e-6
      assert_in_delta item["lon"], -112.1129, 1.0e-6
      assert item["tier1_clue"] == "Steep gorge #1: carved across the Colorado Plateau."
      assert item["tier2_clue"] == "Wait, isn't this in northern Arizona?"

      assert item["tier3_clue"] ==
               "Target telemetry: latitude 36.1 degrees North, longitude 112.1 degrees West."
    end

    test "supports top-level sequence, nested coord mappings, flow mappings, and block scalars" do
      yaml = """
      ---
      - id: wp-nested
        name: "Nested Point"
        coord:
          lat: -12.5
          lon: 45.25
        tier1_clue: >
          A multi-line clue folded
          into a single sentence.
      - name: "Flow Coord Point"
        coord: {lat: 10.0, lon: -20.0}
        tier1_clue: |
          Line one
          Line two
      ...
      """

      assert {:ok, [first, second]} = YamlParser.parse(yaml)
      assert first["coord"] == %{"lat" => -12.5, "lon" => 45.25}
      assert first["tier1_clue"] == "A multi-line clue folded into a single sentence."
      assert second["coord"] == %{"lat" => 10.0, "lon" => -20.0}
      assert second["tier1_clue"] == "Line one\nLine two"
    end

    test "handles CRLF line endings and reports tab or quote errors with line numbers" do
      crlf_yaml =
        "questions:\r\n  - name: Tokyo\r\n    lat: 35.6762\r\n    lon: 139.6503\r\n    tier1_clue: Capital city\r\n"

      assert {:ok, %{"questions" => [item]}} = YamlParser.parse(crlf_yaml)
      assert item["name"] == "Tokyo"

      bad_tabs = "questions:\n\t- name: Broken"
      assert {:error, msg} = YamlParser.parse(bad_tabs)
      assert msg =~ "Line 2"

      unclosed = "questions:\n  - name: \"Open quote\n"
      assert {:error, msg2} = YamlParser.parse(unclosed)
      assert msg2 =~ "Line 2"
    end
  end
end
