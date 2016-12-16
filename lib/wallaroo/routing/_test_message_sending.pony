use "ponytest"
use "wallaroo/test-fixtures"

actor TestMessageSending is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestBackPressureAware)
    test(_TestWatermarkBookkeepingSending)
    test(_TestMessageAndConsumerInteraction)
    None

class iso _TestBackPressureAware is UnitTest
  """
  Verify that sending a message using a back pressure aware message sender
  results in a credit being expended and that we return false to indicate
  that we should stop sending if a message send results in 0 credits being
  available.
  """
  fun name(): String =>
    "message-sending/BackPressureAware"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 2)
    let sender = _BackPressureAwareMessageSender(pool)

    h.assert_eq[ISize](2, pool.available())

    let r1 = _send_on(sender)

    h.assert_eq[ISize](1, pool.available())
    h.assert_true(r1)

    let r2 = _send_on(sender)

    h.assert_eq[ISize](0, pool.available())
    h.assert_false(r2)

  fun _send_on(sender: _MessageSender): Bool =>
    sender.send[String]("hello",
      NullTestProducer,
      NullTestRunnableConsumer,
      1,
      2,
      None,
      NullTestProducer,
      3,
      4,
      NullTestMetricCollector,
      "a test metric",
      5,
      6,
      7,
      8,
      "a test step type")

class iso _TestWatermarkBookkeepingSending is UnitTest
  """
  Verify that watermark bookkeeping is called correctly when sending a message
  via a back pressure aware sender when resilience is turned on.
  """
  fun name(): String =>
    "message-sending/WatermarkBookkeepingSending"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 1)
    let sender = _BackPressureAwareMessageSender(pool)

    let o_route_id = RouteId(101)
    let i_origin = NullTestProducer
    let i_route_id = RouteId(250)
    let i_seq_id = SeqId(1456)

    let btp = BookkeepingTestProducer(h,
      o_route_id,
      i_origin,
      i_route_id,
      i_seq_id)

    ifdef "resilience" then
      h.long_test(1_000_000_000)
      h.expect_action("bookkeeping")
    end

    sender.send[String]("hello",
      btp,
      NullTestRunnableConsumer,
      o_route_id,
      2,
      None,
      i_origin,
      i_route_id,
      i_seq_id,
      NullTestMetricCollector,
      "a test metric",
      5,
      6,
      7,
      8,
      "a test step type")

class iso _TestMessageAndConsumerInteraction is UnitTest
  """
  Verify that _Message correctly interactions with the supplied
  RunnableConsumer
  """
  fun name(): String =>
    "message-sending/MessageAndConsumerInteraction"

  fun apply(h: TestHelper) =>
    let metric_name = "a metric name"
    let pipeline_time_spent = U64(23344)
    let data = "hello world!"
    let outgoing_sequence_id = SeqId(999)
    let producer = SequenceGeneratingProducer(outgoing_sequence_id)
    let msg_uid = U128(8453234933)
    let frac_ids = None
    let o_route_id = RouteId(107)
    let latest_ts = U64(3123213213)
    let metrics_id = U16(16)
    let worker_ingress_ts = U64(773243243)

    let consumer: RunnableConsumer tag = RunTrackingTestRunnableConsumer(h,
      data,
      producer,
      o_route_id,
      outgoing_sequence_id,
      msg_uid,
      frac_ids,
      metric_name,
      metrics_id,
      pipeline_time_spent,
      latest_ts,
      worker_ingress_ts)

    h.long_test(1_000_000_000)
    h.expect_action("consumer run called")

    _Message.send[String val](data,
      producer,
      consumer,
      o_route_id,
      msg_uid,
      frac_ids,
      NullTestMetricCollector,
      metric_name,
      metrics_id,
      pipeline_time_spent,
      latest_ts,
      worker_ingress_ts,
      "foo")

class BookkeepingTestProducer is Producer
  let _h: TestHelper
  let _expected_o_route_id: RouteId
  let _expected_i_origin: Producer
  let _expected_i_route_id: RouteId
  let _expected_i_seq_id: SeqId

  new create(h: TestHelper,
    o_route_id: RouteId,
    i_origin: Producer,
    i_route_id: RouteId,
    i_seq_id: SeqId)
  =>
    _h = h
    _expected_o_route_id = o_route_id
    _expected_i_origin = i_origin
    _expected_i_route_id = i_route_id
    _expected_i_seq_id = i_seq_id

  fun ref _bookkeeping(o_route_id: RouteId, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _h.assert_eq[RouteId](_expected_o_route_id, o_route_id)
    _h.assert_is[Producer](_expected_i_origin, i_origin)
    _h.assert_eq[RouteId](_expected_i_route_id, i_route_id)
    _h.assert_eq[SeqId](_expected_i_seq_id, i_seq_id)
    _h.complete_action("bookkeeping")

  fun desc(): String =>
    "BookkeepingTestProducer"

  fun tag receive_credits(credits: ISize, from: Consumer): Producer tag =>
    this

  fun tag log_flushed(low_watermark: SeqId): Producer tag =>
    this

  fun tag update_watermark(route_id: RouteId, seq_id: SeqId): Producer tag =>
    this

  fun ref recoup_credits(credits: ISize) =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): U64 =>
    0

  fun ref _x_resilience_routes(): Routes =>
    Routes

  fun ref _flush(low_watermark: SeqId) =>
    None

actor RunTrackingTestRunnableConsumer is RunnableConsumer
  let _h: TestHelper
  let _data: String
  let _producer: Producer
  let _o_route_id: RouteId
  let _o_seq_id: SeqId
  let _msg_uid: U128
  let _frac_ids: None
  let _metric_name: String
  let _metrics_id: U16
  let _pipeline_time_spent: U64
  let _latest_ts: U64
  let _worker_ingress_ts: U64

  new create(h: TestHelper,
    data: String,
    producer: Producer,
    o_route_id: RouteId,
    o_seq_id: SeqId,
    msg_uid: U128,
    frac_ids: None,
    metric_name: String,
    metrics_id: U16,
    pipeline_time_spent: U64,
    latest_ts: U64,
    worker_ingress_ts: U64)
  =>
    _h = h
    _data = data
    _producer = producer
    _o_route_id = o_route_id
    _o_seq_id = o_seq_id
    _msg_uid = msg_uid
    _frac_ids = frac_ids
    _metric_name = metric_name
    _metrics_id = metrics_id
    _pipeline_time_spent = pipeline_time_spent
    _latest_ts = latest_ts
    _worker_ingress_ts = worker_ingress_ts

  be run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D,
    origin: Producer, msg_uid: U128,
    frac_ids: None, seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    match data
    | let d: D =>
      _h.assert_eq[String](_metric_name, metric_name)
      _h.assert_eq[U64](_pipeline_time_spent, pipeline_time_spent)
      //_h.assert_is[D](d, data)
      _h.assert_is[Producer](_producer, origin)
      _h.assert_eq[U128](_msg_uid, msg_uid)
      _h.assert_eq[None](_frac_ids, frac_ids)
      _h.assert_eq[SeqId](_o_seq_id, seq_id)
      _h.assert_eq[RouteId](_o_route_id, route_id)
      _h.assert_eq[U64](_latest_ts, latest_ts)
      _h.assert_eq[U16](_metrics_id, metrics_id)
      _h.assert_eq[U64](_worker_ingress_ts, worker_ingress_ts)
      _h.complete_action("consumer run called")
    else
      _h.fail()
    end

  be register_producer(producer: Producer) =>
    None

  be unregister_producer(producer: Producer, credits_returned: ISize) =>
    None

  be credit_request(from: Producer) =>
    None

  be return_credits(credits: ISize) =>
    None

  be replay_run[D: Any val](metric_name: String, pipeline_time_spent: U64,
    data: D, origin: Producer, msg_uid: U128,
    frac_ids: None, incoming_seq_id: SeqId, route_id: RouteId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    None

class SequenceGeneratingProducer is Producer
  let _id: U64
  new create(id: SeqId)
  =>
    _id = id

  fun ref next_sequence_id(): U64 =>
    _id

  fun desc(): String =>
    "SequenceGeneratingProducer"

  fun ref _bookkeeping(o_route_id: RouteId, o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    None

  fun tag receive_credits(credits: ISize, from: Consumer): Producer tag =>
    this

  fun tag log_flushed(low_watermark: SeqId): Producer tag =>
    this

  fun tag update_watermark(route_id: RouteId, seq_id: SeqId): Producer tag =>
    this

  fun ref recoup_credits(credits: ISize) =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref _x_resilience_routes(): Routes =>
    Routes

  fun ref _flush(low_watermark: SeqId) =>
    None
