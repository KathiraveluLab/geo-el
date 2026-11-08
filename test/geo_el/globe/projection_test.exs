defmodule GeoEl.Globe.ProjectionTest do
  use ExUnit.Case, async: true

  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Projection

  describe "forward/3 and inverse/4" do
    test "projects camera center to origin and recovers exact coordinates" do
      camera = Coord.new(25.0, -40.0)
      radius = 220.0

      assert {:ok, {x, y, cos_c}} = Projection.forward(camera, camera, radius)
      assert_in_delta x, 0.0, 1.0e-6
      assert_in_delta y, 0.0, 1.0e-6
      assert_in_delta cos_c, 1.0, 1.0e-6

      assert {:ok, recovered, inv_cos_c} = Projection.inverse(x, y, camera, radius)
      assert_in_delta recovered.lat, camera.lat, 1.0e-4
      assert_in_delta recovered.lon, camera.lon, 1.0e-4
      assert_in_delta inv_cos_c, 1.0, 1.0e-4
    end

    test "round-trips visible hemisphere points between forward and inverse projection" do
      camera = Coord.new(15.0, 10.0)
      point = Coord.new(35.0, 30.0)
      radius = 220.0

      assert {:ok, {x, y, _cos_c}} = Projection.forward(point, camera, radius)
      assert {:ok, recovered, _inv_cos} = Projection.inverse(x, y, camera, radius)

      assert_in_delta recovered.lat, point.lat, 1.0e-3
      assert_in_delta recovered.lon, point.lon, 1.0e-3
    end

    test "enforces BISE radial clamping when click offset exceeds sphere radius" do
      camera = Coord.new(0.0, 0.0)
      radius = 220.0

      assert {:ok, clamped_coord, cos_c} = Projection.inverse(250.0, 250.0, camera, radius)
      assert clamped_coord.lat >= -90.0 and clamped_coord.lat <= 90.0
      assert clamped_coord.lon >= -180.0 and clamped_coord.lon <= 180.0
      assert_in_delta cos_c, 0.0, 1.0e-5
    end
  end
end
