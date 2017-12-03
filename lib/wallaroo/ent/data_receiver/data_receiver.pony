/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "net"
use "time"
use "wallaroo/core/common"
use "wallaroo/core/data_channel"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/ent/watermarking"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/messages"
use "wallaroo/core/routing"
use "wallaroo/core/topology"


actor DataReceiver is Producer
  let _auth: AmbientAuth
  let _worker_name: String
  var _sender_name: String
  var _sender_step_id: StepId = 0
  var _router: DataRouter =
    DataRouter(recover Map[U128, Consumer] end)
  var _last_id_seen: SeqId = 0
  var _last_id_acked: SeqId = 0
  var _connected: Bool = false
  var _reconnecting: Bool = false
  var _ack_counter: USize = 0

  var _last_request: USize = 0

  // TODO: Test replacing this with state machine class
  // to avoid matching on every ack
  var _latest_conn: (DataChannel | None) = None
  var _replay_pending: Bool = false

  let _watermarker: Watermarker = Watermarker

  // Timer to periodically request acks to prevent deadlock.
  var _timer_init: _TimerInit = _UninitializedTimerInit
  let _timers: Timers = Timers

  var _processing_phase: _DataReceiverProcessingPhase =
    _DataReceiverNotProcessingPhase

  var _finished_ack_waiters: Map[U64, FinishedAckWaiter] =
    _finished_ack_waiters.create()

  new create(auth: AmbientAuth, worker_name: String, sender_name: String,
    initialized: Bool = false)
  =>
    _auth = auth
    _worker_name = worker_name
    _sender_name = sender_name
    if initialized then
      _processing_phase = _DataReceiverAcceptingMessagesPhase(this)
    end

  be start_replay_processing() =>
    _processing_phase = _DataReceiverAcceptingReplaysPhase(this)
    // If we've already received a DataConnect, then send ack
    match _latest_conn
    | let conn: DataChannel =>
      _ack_data_connect()
    end

  be start_normal_message_processing() =>
    _processing_phase = _DataReceiverAcceptingMessagesPhase(this)
    _inform_boundary_to_send_normal_messages()

  be data_connect(sender_step_id: StepId, conn: DataChannel) =>
    _sender_step_id = sender_step_id
    _latest_conn = conn
    _processing_phase.data_connect()

  fun _ack_data_connect() =>
    try
      let ack_msg = ChannelMsgEncoder.ack_data_connect(_last_id_seen, _auth)?
      _write_on_conn(ack_msg)
    else
      Fail()
    end

  fun _inform_boundary_to_send_normal_messages() =>
    try
      let start_msg = ChannelMsgEncoder.start_normal_data_sending(_auth)?
      _write_on_conn(start_msg)
    else
      Fail()
    end

  fun _write_on_conn(data: Array[ByteSeq] val) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.writev(data)
    else
      Fail()
    end

  fun ref init_timer() =>
    ifdef "resilience" then
      let t = Timer(_RequestAck(this), 0, 15_000_000)
      _timers(consume t)
    end
    // We are finished initializing timer, so set it to _EmptyTimerInit
    // so we don't create two timers.
    _timer_init = _EmptyTimerInit

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    _watermarker.ack_received(route_id, seq_id)
    try
      let watermark = _watermarker.propose_watermark()

      if watermark > _last_id_acked then
        ifdef "trace" then
          @printf[I32]("DataReceiver acking seq_id %lu\n".cstring(),
            watermark)
        end

        let ack_msg = ChannelMsgEncoder.ack_watermark(_worker_name,
          _sender_step_id, watermark, _auth)?
        _write_on_conn(ack_msg)
        _last_id_acked = watermark
      end
    else
      @printf[I32]("Error creating ack watermark message\n".cstring())
    end

  fun ref flush(low_watermark: SeqId) =>
    """This is not a real Producer, so it doesn't write any State"""
    None

  be request_finished_ack(upstream_producer: FinishedAckRequester, upstream_request_id: U64) =>
    //TODO: receive from upstream over network
    let ack_waiter: FinishedAckWaiter = ack_waiter.create(upstream_request_id,
      upstream_producer)
    let request_id = ack_waiter.add_consumer_request()
    _router.request_finished_ack(request_id, upstream_producer)
    _finished_ack_waiters(request_id) = ack_waiter

  be receive_finished_ack(request_id: U64) =>
    try
      let ack_waiter = _finished_ack_waiters(request_id)?
      ack_waiter.unmark_consumer_request(request_id)
      if ack_waiter.should_send_upstream() then
        let ack_msg = ChannelMsgEncoder.finished_ack(
          ack_waiter.upstream_request_id, _auth)?
        _write_on_conn(ack_msg)
      end
    else
      Fail()
    end

  //////////////
  // ORIGIN (resilience)
  fun ref _acker(): Acker =>
    // TODO: I dont think we need this.
    // Need to discuss with John
    Acker

  fun ref bookkeeping(route_id: RouteId, seq_id: SeqId) =>
    """
    Process envelopes and keep track of things
    """
    ifdef "trace" then
      @printf[I32]("Bookkeeping called for DataReceiver route %lu\n".cstring(),
        route_id)
    end
    ifdef "resilience" then
      _watermarker.sent(route_id, seq_id)
    end

  be update_router(router: DataRouter) =>
    // TODO: This commented line conflicts with invariant downstream. The
    // idea is to unregister if we've registered but not otherwise.
    // The invariant says you can only call this method on a step if
    // you've already registered. If we allow calling it whether or not
    // you've registered, this will work, but that might cause other
    // problems. However, otherwise, when updating, we might register twice
    // with the same step or never unregister with one we'll no longer
    // be sending to.
    // Currently, this behavior should only be called once in the lifecycle
    // of a DataReceiver, so we would only need this if that were to change.
    //_router.unregister_producer(this, 0)

    _router = router
    _router.register_producer(this)
    for id in _router.route_ids().values() do
      _watermarker.add_route(id)
    end

  be received(d: DeliveryMsg, pipeline_time_spent: U64, seq_id: SeqId,
    latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    _timer_init(this)
    ifdef "trace" then
      @printf[I32]("Rcvd pipeline msg at DataReceiver\n".cstring())
    end
    if seq_id > _last_id_seen then
      _ack_counter = _ack_counter + 1
      _last_id_seen = seq_id
      _router.route(d, pipeline_time_spent, this, seq_id, latest_ts,
        metrics_id, worker_ingress_ts)
      _maybe_ack()
    end

  be request_ack() =>
    if _last_id_acked < _last_id_seen then
      _request_ack()
    end

  fun ref _request_ack() =>
    _router.request_ack(_watermarker.unacked_route_ids())
    _last_request = _ack_counter

  be replay_received(r: ReplayableDeliveryMsg, pipeline_time_spent: U64,
    seq_id: SeqId, latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)
  =>
    if seq_id > _last_id_seen then
      _last_id_seen = seq_id
      _router.replay_route(r, pipeline_time_spent, this, seq_id, latest_ts,
        metrics_id, worker_ingress_ts)
    end

  fun ref _maybe_ack() =>
    ifdef not "resilience" then
      if (_ack_counter % 512) == 0 then
        _ack_latest()
      end
    end

  fun ref _ack_latest() =>
    try
      if _last_id_seen > _last_id_acked then
        ifdef "trace" then
          @printf[I32]("DataReceiver acking seq_id %lu\n".cstring(),
            _last_id_seen)
        end
        _last_id_acked = _last_id_seen
        let ack_msg = ChannelMsgEncoder.ack_watermark(_worker_name,
          _sender_step_id, _last_id_seen, _auth)?
        _write_on_conn(ack_msg)
      end
    else
      @printf[I32]("Error creating ack watermark message\n".cstring())
    end

  be dispose() =>
    @printf[I32]("Shutting down DataReceiver\n".cstring())
    _timers.dispose()
    match _latest_conn
    | let conn: DataChannel =>
      conn.dispose()
    end

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0

  be mute(c: Consumer) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.mute(c)
    end

  be unmute(c: Consumer) =>
    match _latest_conn
    | let conn: DataChannel =>
      conn.unmute(c)
    end


trait _DataReceiverProcessingPhase
  fun data_connect() =>
    None

class _DataReceiverNotProcessingPhase is _DataReceiverProcessingPhase

class _DataReceiverAcceptingReplaysPhase is _DataReceiverProcessingPhase
  let _data_receiver: DataReceiver ref

  new create(dr: DataReceiver ref) =>
    _data_receiver = dr

  fun data_connect() =>
    _data_receiver._ack_data_connect()

class _DataReceiverAcceptingMessagesPhase is _DataReceiverProcessingPhase
  let _data_receiver: DataReceiver ref

  new create(dr: DataReceiver ref) =>
    _data_receiver = dr

  fun data_connect() =>
    _data_receiver._ack_data_connect()
    _data_receiver._inform_boundary_to_send_normal_messages()

trait _TimerInit
  fun apply(d: DataReceiver ref)

class _UninitializedTimerInit is _TimerInit
  fun apply(d: DataReceiver ref) =>
    d.init_timer()

class _EmptyTimerInit is _TimerInit
  fun apply(d: DataReceiver ref) => None

class _RequestAck is TimerNotify
  let _d: DataReceiver

  new iso create(d: DataReceiver) =>
    _d = d

  fun ref apply(timer: Timer, count: U64): Bool =>
    _d.request_ack()
    true
