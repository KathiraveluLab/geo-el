defmodule GeoEl.Globe.WorldDataTest do
  use ExUnit.Case, async: false

  alias GeoEl.Globe.WorldData

  describe "YAML question bank loading and hot reload" do
    test "loads all 24 questions from priv/data/questions.yaml without hardcoded literals" do
      assert File.exists?(WorldData.questions_path())
      waypoints = WorldData.waypoints()
      assert length(waypoints) == 24
      assert WorldData.expedition_size() == 6
    end

    test "parses minimal teacher YAML entries with auto-generated id, region, and hints" do
      yaml = """
      expedition_size: 2

      questions:
        - name: "Petra, Ma'an"
          lat: 30.3285
          lon: 35.4444
          tier1_clue: "Locate the rose-red rock-cut ancient trading city carved into sandstone canyons."
        - name: "Angkor Wat"
          coord:
            lat: 13.4125
            lon: 103.8670
          region: "Northern Cambodia"
          tier1_clue: "Identify the vast sandstone temple complex surrounded by a rectangular moat."
      """

      {waypoints, size} = WorldData.parse_questions_yaml!(yaml, "teacher_quiz.yaml")
      assert size == 2
      assert [petra, angkor] = waypoints

      assert petra.id == "wp-petra-ma-an-1"
      assert petra.region == "Global Landmark"
      assert petra.tier2_clue == "Located in Global Landmark."
      assert petra.tier3_clue =~ "latitude 30.3 degrees North"

      assert angkor.name == "Angkor Wat"
      assert angkor.tier2_clue == "Located in Northern Cambodia."
      assert_in_delta angkor.coord.lat, 13.4125, 1.0e-4
      assert_in_delta angkor.coord.lon, 103.8670, 1.0e-4
    end

    test "validates coordinate bounds and duplicate IDs via BISE" do
      bad_coords_yaml = """
      questions:
        - id: wp-bad
          name: "Off Earth"
          lat: 120.0
          lon: 10.0
          tier1_clue: "Invalid latitude should raise."
      """

      assert_raise ArgumentError, ~r/out of bounds/, fn ->
        WorldData.parse_questions_yaml!(bad_coords_yaml, "bad.yaml")
      end

      duplicate_yaml = """
      questions:
        - id: wp-dup
          name: "First"
          lat: 10.0
          lon: 10.0
          tier1_clue: "Clue 1"
        - id: wp-dup
          name: "Second"
          lat: 20.0
          lon: 20.0
          tier1_clue: "Clue 2"
      """

      assert_raise ArgumentError, ~r/Duplicate question id/, fn ->
        WorldData.parse_questions_yaml!(duplicate_yaml, "dup.yaml")
      end
    end

    test "reloads automatically when configured questions YAML file is updated on disk" do
      temp_path =
        Path.join(
          System.tmp_dir!(),
          "geo_el_questions_#{System.unique_integer([:positive])}.yaml"
        )

      initial_yaml = """
      questions:
        - id: wp-temp-1
          name: "Machu Picchu"
          lat: -13.1631
          lon: -72.5450
          tier1_clue: "Locate the 15th-century Inca citadel high in the Peruvian Andes."
      """

      File.write!(temp_path, initial_yaml)
      Application.put_env(:geo_el, :questions_path, temp_path)

      on_exit(fn ->
        Application.delete_env(:geo_el, :questions_path)
        WorldData.reload_questions!()
        File.rm(temp_path)
      end)

      WorldData.reload_questions!()
      assert Enum.map(WorldData.waypoints(), & &1.id) == ["wp-temp-1"]
      assert WorldData.expedition_size() == 1

      updated_yaml =
        initial_yaml <>
          """
            - id: wp-temp-2
              name: "Colosseum, Rome"
              lat: 41.8902
              lon: 12.4922
              tier1_clue: "Find the elliptical travertine amphitheatre beside the Tiber Valley."
          """

      File.write!(temp_path, updated_yaml)
      # Force distinct mtime for filesystems with coarse timestamp resolution
      File.touch!(temp_path, {{2030, 1, 1}, {12, 0, 5}})

      assert Enum.map(WorldData.waypoints(), & &1.id) == ["wp-temp-1", "wp-temp-2"]
      assert WorldData.expedition_size() == 2
    end
  end
end
