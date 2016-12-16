use "wallaroo/routing"
use "wallaroo/topology"

actor NullTestRunnableConsumer is RunnableConsumer
  fun tag register_producer(producer: Producer): RunnableConsumer tag =>
    this

  fun tag unregister_producer(producer: Producer, credits_returned: ISize): RunnableConsumer tag
   =>
    this

  fun tag credit_request(from: Producer): RunnableConsumer tag =>
    this

  fun tag return_credits(credits: ISize): RunnableConsumer tag =>
    this

  fun tag run[D: Any val](metric_name: String, pipeline_time_spent: U64, data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
    : RunnableStep tag
  =>
    this

  fun tag replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, origin: Producer, msg_uid: U128,
    frac_ids: None, incoming_seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
    : RunnableConsumer tag
  =>
    this
