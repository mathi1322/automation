def average_of(*metrics)
  metrics_without_endash = metrics.reject{|arr| arr == "–" }
  count = metrics_without_endash.count
  average = ((metrics.collect{ |metric| metric.to_i}.sum * 1.0) / count).round.to_s
end
