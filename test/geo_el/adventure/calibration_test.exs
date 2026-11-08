defmodule GeoEl.Adventure.CalibrationTest do
  use ExUnit.Case, async: true

  alias GeoEl.Adventure.Calibration

  describe "compute_score/4" do
    test "returns 1.0 for zero distance residual and decays monotonically with distance" do
      s0 = Calibration.compute_score(0.0, 0.0, 1.0)
      s500 = Calibration.compute_score(500.0, 0.0, 1.0)
      s2000 = Calibration.compute_score(2000.0, 0.0, 1.0)

      assert_in_delta s0, 1.0, 1.0e-6
      assert s500 < s0 and s500 > s2000
      assert s2000 > 0.0
    end

    test "compensates for perspective foreshortening near the horizon limb" do
      score_center = Calibration.compute_score(800.0, 0.2, 1.0)
      score_horizon = Calibration.compute_score(800.0, 0.2, 0.4)

      assert score_horizon > score_center
    end
  end

  describe "confidence_interval_95/1" do
    test "computes bounded 95% confidence interval for proficiency samples" do
      scores = [0.82, 0.76, 0.88, 0.79, 0.85]
      {mean, lower, upper} = Calibration.confidence_interval_95(scores)

      assert_in_delta mean, 0.82, 1.0e-3
      assert lower < mean and lower >= 0.0
      assert upper > mean and upper <= 1.0
    end
  end
end

