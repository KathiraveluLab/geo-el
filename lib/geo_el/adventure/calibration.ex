defmodule GeoEl.Adventure.Calibration do
  @moduledoc """
  Implements SkewPNN skewed exponential proficiency scoring, A2 adaptive clue routing,
  and 95% confidence interval estimation across geographic target strata.
  """

  @default_sigma0 1500.0
  @default_alpha 0.35

  @doc """
  Computes the normalized proficiency score `S_k` in `[0.0, 1.0]` using the SkewPNN kernel:
  `S_k = exp(-d_k / (sigma0 * (1 + alpha * |gamma_k|) * foreshortening_adjustment))`.
  """
  @spec compute_score(number(), number(), number(), keyword()) :: float()
  def compute_score(distance_km, skewness_gamma, cos_c \\ 1.0, opts \\ [])
      when is_number(distance_km) and is_number(skewness_gamma) and is_number(cos_c) do
    sigma0 = Keyword.get(opts, :sigma0, @default_sigma0)
    alpha = Keyword.get(opts, :alpha, @default_alpha)

    safe_d = max(0.0, distance_km * 1.0)
    safe_cos = max(0.35, min(1.0, abs(cos_c * 1.0)))
    effective_sigma = sigma0 * (1.0 + alpha * abs(skewness_gamma * 1.0)) / safe_cos

    :math.exp(-safe_d / effective_sigma)
  end

  @doc """
  Updates the empirical skewness estimate `gamma_k` from a list of observed geodesic distance residuals.
  Applies Bayesian warm-up blending when fewer than three residual samples are present.
  """
  @spec estimate_skewness([float()]) :: float()
  def estimate_skewness(residuals) when is_list(residuals) do
    n = length(residuals)

    if n < 3 do
      0.0
    else
      mean = Enum.sum(residuals) / n

      variance =
        residuals
        |> Enum.map(fn r -> (r - mean) * (r - mean) end)
        |> Enum.sum()
        |> Kernel./(n)

      std_dev = :math.sqrt(max(1.0e-6, variance))

      raw_skew =
        residuals
        |> Enum.map(fn r -> :math.pow((r - mean) / std_dev, 3) end)
        |> Enum.sum()
        |> Kernel./(n)

      warm_weight = min(1.0, n / 6.0)
      Float.round(warm_weight * raw_skew, 4)
    end
  end

  @doc """
  Determines the recommended clue tier (`1`, `2`, or `3`) via the A2 adaptive controller
  based on the player's latest proficiency score `S_k`.
  """
  @spec recommend_clue_tier(float()) :: 1 | 2 | 3
  def recommend_clue_tier(score) when is_number(score) do
    cond do
      score >= 0.65 -> 1
      score >= 0.35 -> 2
      true -> 3
    end
  end

  @doc """
  Computes the sample mean and 95% confidence interval `{mean, lower_bound, upper_bound}`
  for a list of proficiency scores `S_k` in `[0.0, 1.0]`.
  """
  @spec confidence_interval_95([float()]) :: {float(), float(), float()}
  def confidence_interval_95([]), do: {1.0, 1.0, 1.0}

  def confidence_interval_95([single]) do
    clamped = clamp_score(single)
    {clamped, clamped, clamped}
  end

  def confidence_interval_95(scores) when is_list(scores) do
    n = length(scores)
    mean = Enum.sum(scores) / n

    sample_variance =
      scores
      |> Enum.map(fn s -> (s - mean) * (s - mean) end)
      |> Enum.sum()
      |> Kernel./(n - 1)

    std_error = :math.sqrt(max(0.0, sample_variance) / n)
    margin = 1.96 * std_error

    {
      Float.round(mean, 4),
      Float.round(clamp_score(mean - margin), 4),
      Float.round(clamp_score(mean + margin), 4)
    }
  end

  defp clamp_score(val) when val > 1.0, do: 1.0
  defp clamp_score(val) when val < 0.0, do: 0.0
  defp clamp_score(val), do: val * 1.0
end

