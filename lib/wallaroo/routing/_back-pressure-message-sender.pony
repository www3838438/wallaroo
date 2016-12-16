use "time"
use "wallaroo/invariant"
use "wallaroo/metrics"
use "wallaroo/topology"

type RunnableConsumer is (Consumer & RunnableStep)

primitive _Message
  fun send[In: Any val](input: In,
    producer: Producer ref,
    consumer: RunnableConsumer,
    o_route_id: RouteId,
    msg_uid: U128,
    frac_ids: None,
    metrics_reporter: MetricCollector,
    metric_name: String,
    metrics_id: U16,
    pipeline_time_spent: U64,
    latest_ts: U64,
    worker_ingress_ts: U64,
    sending_step_type: String) : SeqId
  =>
    let o_seq_id = producer.next_sequence_id()

    let my_latest_ts = ifdef "detailed-metrics" then
        Time.nanos()
      else
        latest_ts
      end

    let new_metrics_id = ifdef "detailed-metrics" then
        metrics_reporter.step_metric(metric_name,
          "Before send to next step via behavior", metrics_id,
          latest_ts, my_latest_ts)
        metrics_id + 1
      else
        metrics_id
      end

    ifdef "trace" then
      @printf[I32]("Sending msg from Route (%s)\n".cstring(),
        sending_step_type.cstring())
    end

    consumer.run[In](metric_name,
      pipeline_time_spent,
      input,
      producer,
      msg_uid,
      frac_ids,
      o_seq_id,
      o_route_id,
      my_latest_ts,
      new_metrics_id,
      worker_ingress_ts)

    o_seq_id

interface _MessageSender
  fun ref send[In: Any val](input: In,
    producer: Producer ref,
    consumer: RunnableConsumer,
    route_id: RouteId,
    msg_uid: U128,
    frac_ids: None,
    i_origin: Producer,
    i_route_id: RouteId,
    i_seq_id: SeqId,
    metrics_reporter: MetricCollector,
    metric_name: String,
    metrics_id: U16,
    pipeline_time_spent: U64,
    latest_ts: U64,
    worker_ingress_ts: U64,
    sending_step_type: String): Bool

class _BackPressureIgnorantMessageSender
  fun ref send[In: Any val](input: In,
    producer: Producer ref,
    consumer: RunnableConsumer,
    route_id: RouteId,
    msg_uid: U128,
    frac_ids: None,
    i_origin: Producer,
    i_route_id: RouteId,
    i_seq_id: SeqId,
    metrics_reporter: MetricCollector,
    metric_name: String,
    metrics_id: U16,
    pipeline_time_spent: U64,
    latest_ts: U64,
    worker_ingress_ts: U64,
    sending_step_type: String): Bool
  =>
    _Message.send[In](input,
      producer,
      consumer,
      route_id,
      msg_uid,
      frac_ids,
      metrics_reporter,
      metric_name,
      metrics_id,
      pipeline_time_spent,
      latest_ts,
      worker_ingress_ts,
      sending_step_type)
    true

class _BackPressureAwareMessageSender
  let _credits: _CreditPool

  new create(credits: _CreditPool) =>
    _credits = credits

  fun ref send[In: Any val](input: In,
    producer: Producer ref,
    consumer: RunnableConsumer,
    route_id: RouteId,
    msg_uid: U128,
    frac_ids: None,
    i_origin: Producer,
    i_route_id: RouteId,
    i_seq_id: SeqId,
    metrics_reporter: MetricCollector,
    metric_name: String,
    metrics_id: U16,
    pipeline_time_spent: U64,
    latest_ts: U64,
    worker_ingress_ts: U64,
    sending_step_type: String): Bool
  =>
    ifdef debug then
      Invariant(_credits.available() > 0)
    end

    let o_seq_id = _Message.send[In](input,
      producer,
      consumer,
      route_id,
      msg_uid,
      frac_ids,
      metrics_reporter,
      metric_name,
      metrics_id,
      pipeline_time_spent,
      latest_ts,
      worker_ingress_ts,
      sending_step_type)

    ifdef "resilience" then
      producer._bookkeeping(route_id, o_seq_id, i_origin, i_route_id, i_seq_id)
    end

    _credits.expend()
    _credits.available() > 0
