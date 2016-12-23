use "sendence/guid"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"

trait Route
  fun ref application_created()
  fun ref application_initialized(new_max_credits: ISize, step_type: String)
  fun id(): U64
  fun ref receive_credits(credits: ISize)
  fun ref dispose()
  // Return false to indicate queue is full and if producer is a Source, it
  // should mute
  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId, latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64): Bool

trait RouteLogic
  fun credits_available(): ISize
  fun max_credits(): ISize
  fun ref _credits_initialized()
  fun ref _credits_replenished()
  fun ref register_with_callback()
  fun ref application_initialized(new_max_credits: ISize, step_type: String)
  fun ref receive_credits(credits: ISize)
  fun ref dispose()
  fun ref try_request(): Bool
  fun ref use_credit()
  fun ref _credits_exhausted()
  fun ref _request_credits()
  fun ref _credits_overflowed(by: ISize)
 fun ref _recoup_credits(credits: ISize)

class _RouteLogic is RouteLogic
  let _step: Producer ref
  let _consumer: Consumer
  var _step_type: String = ""
  var _route_type: String = ""
  let _callback: RouteCallbackHandler
  var _max_credits: ISize
  var _credits_available: ISize = 0
  var _request_more_credits_after: ISize = 0
  var _request_outstanding: Bool = false
  var _credit_receiver: _CreditReceiver

  new create(step: Producer ref, consumer: Consumer,
    handler: RouteCallbackHandler, r_type: String, max_credits': ISize = 0)
  =>
    _step = step
    _consumer = consumer
    _callback = handler
    _route_type = r_type
    _max_credits = max_credits'
    _credit_receiver = _NotYetReadyRoute

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    _step_type = step_type
    ifdef "backpressure" then
      ifdef debug then
        Invariant(new_max_credits > 0)
      end
      _max_credits = new_max_credits

      //_request_credits()
    end

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits_available)

  fun ref register_with_callback() =>
    _callback.register(_step, this)

  fun credits_available(): ISize =>
    _credits_available

  fun ref use_credit() =>
    _credits_available = _credits_available - 1

  fun max_credits(): ISize =>
    _max_credits

  fun ref receive_credits(credits: ISize) =>
     ifdef debug then
      Invariant(credits > 0)
    end

    _credit_receiver.preconditions(this, credits)

    let started_from_zero = credits_available() == 0
    _request_outstanding = false

    let credits_recouped =
      if (credits_available() + credits) > max_credits() then
        max_credits() - credits_available()
      else
        credits
      end
    _recoup_credits(credits_recouped)

    if credits > credits_recouped then
      _return_credits(credits - credits_recouped)
    end

    ifdef "credit_trace" then
      @printf[I32](("-Route (%s): rcvd %llu credits." +
        " Had %llu out of %llu.\n").cstring(),
        _credit_receiver.state(),
        credits, credits_available() - credits_recouped,
        max_credits())
    end

    _update_request_more_credits_after(
      credits_available() - (credits_available() >> 2))

    _credit_receiver.action(this, started_from_zero)

  fun ref try_request(): Bool =>
    if _credits_available == 0 then
      //_credits_exhausted()
      @printf[None]("SHOUNDNT BE HERE\n".cstring())
      return false
    else
      if (_credits_available + 1) == _request_more_credits_after then
        // we started above the request size and finished below,
        // request credits
        _request_credits()
      end
    end
    true

  fun ref _credits_initialized() =>
    _callback.credits_initialized(_step)
    _report_ready_to_work()

  fun ref _report_ready_to_work() =>
    _credit_receiver = _ReadyRoute
    match _step
    | let s: Step ref =>
      s.report_route_ready_to_work(this)
    end

  fun ref _recoup_credits(credits: ISize) =>
    _credits_available = _credits_available + credits
    _step.recoup_credits(credits)

  fun ref _credits_exhausted() =>
    @printf[None]("Route(%s) cr exhausted\n".cstring(), _step_type.cstring())
    _callback.credits_exhausted(_step)
    //_request_credits()

  fun ref _credits_replenished() =>
    _callback.credits_replenished(_step)

  fun ref _update_request_more_credits_after(credits: ISize) =>
    _request_more_credits_after = credits

  fun ref _request_credits() =>
    if not _request_outstanding then
      ifdef "credit_trace" then
        @printf[I32]("--Route (%s): requesting credits. Have %llu\n"
          .cstring(), _step_type.cstring(), _credits_available)
      end
      _consumer.credit_request(_step)
      _request_outstanding = true
    else
      ifdef "credit_trace" then
        @printf[I32]("----Route (%s): Request already outstanding\n"
          .cstring(), _step_type.cstring())
      end
    end

  fun ref _return_credits(credits: ISize) =>
    _consumer.return_credits(credits)

  fun ref _credits_overflowed(credits: ISize) =>
    _return_credits(credits)

class _EmptyRouteLogic is RouteLogic
  fun credits_available(): ISize =>
    Fail()
    0

  fun max_credits(): ISize =>
    Fail()
    0

  fun _credits_initialized() =>
    Fail()
    None

  fun _credits_replenished() =>
    Fail()
    None

  fun ref register_with_callback() =>
    Fail()
    None

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    Fail()
    None

  fun ref receive_credits(credits: ISize) =>
    Fail()
    None

  fun ref dispose() =>
    Fail()
    None

  fun ref try_request(): Bool =>
    Fail()
    true

  fun ref use_credit() =>
    Fail()
    None

  fun ref _credits_exhausted() =>
    Fail()
    None

  fun ref _request_credits() =>
    Fail()
    None

  fun ref _credits_overflowed(credits: ISize) =>
    Fail()
    None

 fun ref _recoup_credits(credits: ISize) =>
    Fail()
    None

class EmptyRoute is Route
  let _route_id: U64 = 1 + GuidGenerator.u64()

  fun ref application_created() =>
    None

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    None

  fun id(): U64 => _route_id
  fun ref update_max_credits(max_credits: ISize) => None
  fun credits_available(): ISize => 0
  fun ref dispose() => None
  fun ref request_credits() => None
  fun ref receive_credits(number: ISize) => None

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    true

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId, latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64): Bool
  =>
    true
