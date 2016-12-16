use "wallaroo/routing"

class NullTestProducer is Producer
  fun desc(): String =>
    "NullTestProduer"

  fun tag receive_credits(credits: ISize, from: Consumer): Producer tag =>
    this

  fun tag log_flushed(low_watermark: SeqId): Producer tag =>
    this

  fun tag update_watermark(route_id: RouteId, seq_id: SeqId): Producer tag =>
    this

  fun ref recoup_credits(credits: ISize) =>
    None

  fun ref credits_exhausted() =>
    None

  fun ref credits_initialized() =>
    None

  fun ref report_route_ready_to_work(r: (CreditRequester | RouteLogic)) =>
    None

  fun ref credits_replenished() =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): U64 =>
    0

  fun ref _x_resilience_routes(): Routes =>
    Routes

  fun ref _flush(low_watermark: SeqId) =>
    None

  fun ref _bookkeeping(o_route_id: RouteId, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId) =>
    None
