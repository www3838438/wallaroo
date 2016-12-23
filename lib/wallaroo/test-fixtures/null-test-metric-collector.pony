use "wallaroo/metrics"

class NullTestMetricCollector is MetricCollector
  fun ref step_metric(pipeline: String, name: String, id: U16,
    start_ts: U64, end_ts: U64, prefix: String = "")
  =>
    None
