use "time"
use "sendence/guid"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/tcp-source"
use "wallaroo/topology"

class TypedRoute[In: Any val] is Route
  """
  Relationship between a single producer and a single consumer.
  """
  let _route_id: U64 = 1 + GuidGenerator.u64() // route 0 is used for filtered messages
  var _step_type: String = ""
  let _step: Producer ref
  let _consumer: CreditFlowConsumerStep
  let _metrics_reporter: MetricsReporter
  let _credits: _CreditPool
  let _message_sender: _MessageSender
  let _credit_requester: CreditRequester

  new create(step: Producer ref, consumer: CreditFlowConsumerStep,
    handler: RouteCallbackHandler, metrics_reporter: MetricsReporter ref)
  =>
    _step = step
    _consumer = consumer
    _metrics_reporter = metrics_reporter
    _credits = _CreditPool
    _credit_requester = CreditRequester(step, consumer, _credits)
    _message_sender = ifdef "backpressure" then
      _BackPressureAwareMessageSender(_credits)
    else
      _BackPressureIgnorantMessageSender
    end

  fun desc(): String =>
    _step_type

  fun ref application_created() =>
    _consumer.register_producer(_step)

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    _step_type = step_type

    ifdef "backpressure" then
      _credits.change_max(new_max_credits)
      _credit_requester.request()
    end


  fun id(): U64 =>
    _route_id

  fun ref receive_credits(credits: ISize) =>
    _credit_requester.receive(credits)
   // _route.receive_credits(credits)

  fun ref dispose() =>
    """
    Return unused credits to downstream consumer
    """
    _consumer.unregister_producer(_step, _credits.available())

  fun ref run[D](metric_name: String, pipeline_time_spent: U64, data: D,
    cfp: Producer ref,
    origin: Producer, msg_uid: U128,
    frac_ids: None, i_seq_id: SeqId, i_route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64): Bool
  =>
    ifdef "trace" then
      @printf[I32]("--Rcvd msg at Route (%s)\n".cstring(),
        _step_type.cstring())
    end
    match data
    | let input: In =>
      ifdef debug then
        match _step
        | let source: TCPSource ref =>
          Invariant(not source.is_muted())
        end
      end

      _message_sender.send[In](input,
        cfp, _consumer,_route_id,
        msg_uid, frac_ids,
        origin, i_route_id, i_seq_id,
        _metrics_reporter, metric_name, metrics_id,
        pipeline_time_spent, latest_ts, worker_ingress_ts,
        _step_type)
    else
      Fail()
      true
    end

  fun ref forward(delivery_msg: ReplayableDeliveryMsg val,
    pipeline_time_spent: U64, cfp: Producer ref,
    i_origin: Producer, msg_uid: U128, i_frac_ids: None, i_seq_id: SeqId,
    i_route_id: RouteId, latest_ts: U64, metrics_id: U16, metric_name: String,
    worker_ingress_ts: U64): Bool
  =>
    // Forward should never be called on a TypedRoute
    Fail()
    true
