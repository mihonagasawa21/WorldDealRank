# frozen_string_literal: true

module GradeCuts
  module_function

  # scores: 配列（数値）。必ず sort 済みで渡す
  def from_sorted_scores(scores)
    return { s: 100.0, a: 100.0, b: 100.0, c: 100.0 } if scores.empty?

    {
      s: percentile(scores, 0.80), # 上位20%がS
      a: percentile(scores, 0.60),
      b: percentile(scores, 0.40),
      c: percentile(scores, 0.20)
    }
  end

  def percentile(sorted, p)
    n = sorted.length
    return sorted[0] if n == 1
    idx = (p * (n - 1)).round
    sorted[idx]
  end
end
