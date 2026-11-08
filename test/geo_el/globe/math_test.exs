defmodule GeoEl.Globe.MathTest do
  use ExUnit.Case, async: true

  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Math

  describe "visible?/2 and cos_central_angle/2" do
    test "returns true for camera center and points within 90 degrees" do
      camera = Coord.new(0.0, 0.0)
      assert Math.visible?(Coord.new(0.0, 0.0), camera)
      assert Math.visible?(Coord.new(45.0, 45.0), camera)
    end

    test "returns false for antipodal points on the occluded hemisphere" do
      camera = Coord.new(0.0, 0.0)
      refute Math.visible?(Coord.new(0.0, 180.0), camera)
      refute Math.visible?(Coord.new(-30.0, 150.0), camera)
    end
  end

  describe "haversine_distance/2" do
    test "returns zero distance for identical coordinates" do
      origin = Coord.new(51.4769, 0.0005)
      assert_in_delta Math.haversine_distance(origin, origin), 0.0, 1.0e-5
    end

    test "satisfies symmetry and computes accurate quarter-sphere arc length" do
      equator_prime = Coord.new(0.0, 0.0)
      north_pole = Coord.new(90.0, 0.0)

      d1 = Math.haversine_distance(equator_prime, north_pole)
      d2 = Math.haversine_distance(north_pole, equator_prime)

      assert_in_delta d1, d2, 1.0e-6
      assert_in_delta d1, 10_007.55, 1.0
    end
  end

  describe "interpolate_arc/3" do
    test "generates intermediate coordinates along the great circle" do
      origin = Coord.new(0.0, 0.0)
      target = Coord.new(0.0, 60.0)

      arc = Math.interpolate_arc(origin, target, 6)
      assert length(arc) == 7

      midpoint = Enum.at(arc, 3)
      assert_in_delta midpoint.lat, 0.0, 1.0e-3
      assert_in_delta midpoint.lon, 30.0, 1.0e-3
    end
  end
end

