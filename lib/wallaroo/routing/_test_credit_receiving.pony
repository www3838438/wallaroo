use "ponytest"
use "wallaroo/test-fixtures"

actor TestCreditReceiving is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestReceiveCreditsBelowMax)
    test(_TestReceiveCreditsCrossingMax)
    test(_TestNotYetReadyRouteInteractions)
    test(_TestReadyRouteWithoutCreditsInteractions)
    //test(_TestReadyRouteWithCreditsInteractions)


class iso _TestReceiveCreditsBelowMax is UnitTest
  fun name(): String =>
    "credit-receiving/TestReceiveCreditsBelowMax"

  fun ref apply(h: TestHelper) =>
    let rl = _RouteLogic(NullTestProducer,
      ConsumerThatDoesntGetCreditsReturned(h),
      NullRouteCallbackHandler,
      "",
      50)

    rl.receive_credits(10)
    h.assert_eq[ISize](10, rl.credits_available())
    rl.receive_credits(15)
    h.assert_eq[ISize](25, rl.credits_available())
    rl.receive_credits(20)
    h.assert_eq[ISize](45, rl.credits_available())

class iso _TestReceiveCreditsCrossingMax is UnitTest
  fun name(): String =>
    "credit-receiving/TestReceiveCreditsCrossingMax"

  fun ref apply(h: TestHelper) =>
    let rl = _RouteLogic(NullTestProducer,
      ConsumerThatGetsCreditsReturned(h, 20),
      NullRouteCallbackHandler,
      "",
      50)

    rl.receive_credits(10)
    h.assert_eq[ISize](10, rl.credits_available())
    rl.receive_credits(15)
    h.assert_eq[ISize](25, rl.credits_available())
    rl.receive_credits(20)
    h.assert_eq[ISize](45, rl.credits_available())
    rl.receive_credits(25)
    h.assert_eq[ISize](50, rl.credits_available())
    rl.receive_credits(20)
    h.assert_eq[ISize](50, rl.credits_available())
    rl.receive_credits(20)
    h.assert_eq[ISize](50, rl.credits_available())

class iso _TestNotYetReadyRouteInteractions is UnitTest
  fun name(): String =>
    "credit-receiving/TestNotYetReadyRouteInteractions"

  fun ref apply(h: TestHelper) =>
    let route = _ANotYetReadyRoute(h)
    let cr: _CreditReceiver ref = _NotYetReadyRoute

    h.expect_action("credits initialized")
    cr.preconditions(route, 5)
    cr.action(route, false)

class iso _TestReadyRouteWithoutCreditsInteractions is UnitTest
  fun name(): String =>
    "credit-receiving/TestReadyRouteWithoutCreditsInteractions"

  fun ref apply(h: TestHelper) =>
    let has_credits = false
    let route = _AReadyRoute(h, has_credits)
    let cr: _CreditReceiver ref = _ReadyRoute

    h.expect_action("credits replenished")
    cr.preconditions(route, 5)
    cr.action(route, not has_credits)

/*
// This test is not yet expressable with Pony Test.
class iso _TestReadyRouteWithCreditsInteractions is UnitTest
  fun name(): String =>
    "credit-receiving/TestReadyRouteWithCreditsInteractions"

  fun ref apply(h: TestHelper) =>
    let has_credits = true
    let route = _AReadyRoute(h, has_credits)
    let cr: _CreditReceiver ref = _ReadyRoute

    h.deny_action("credits replenished")
    cr.preconditions(route, 5)
    cr.action(route, not has_credits)
*/

class _ANotYetReadyRoute is RouteLogic
  let _h: TestHelper

  new ref create(h: TestHelper) =>
    _h = h

  fun credits_available(): ISize =>
    0

  fun max_credits(): ISize =>
    0

  fun _credits_initialized() =>
    _h.complete_action("credits initialized")

  fun _credits_replenished() =>
    _h.fail()

  fun ref register_with_callback() =>
    None

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    None

  fun ref receive_credits(credits: ISize) =>
    None

  fun ref dispose() =>
    None

  fun ref try_request(): Bool =>
    true

  fun ref use_credit() =>
    None

class _AReadyRoute is RouteLogic
  let _h: TestHelper
  var _credits_available: ISize = 0

  new ref create(h: TestHelper, has_credits: Bool) =>
    _h = h
    if has_credits then
      _credits_available = 20
    end

  fun credits_available(): ISize =>
    _credits_available

  fun max_credits(): ISize =>
    50

  fun _credits_initialized() =>
    _h.fail()

  fun _credits_replenished() =>
    _h.complete_action("credits replenished")

  fun ref register_with_callback() =>
    None

  fun ref application_initialized(new_max_credits: ISize, step_type: String) =>
    None

  fun ref receive_credits(credits: ISize) =>
    None

  fun ref dispose() =>
    None

  fun ref try_request(): Bool =>
    true

  fun ref use_credit() =>
    None

actor ConsumerThatGetsCreditsReturned is Consumer
  let _h: TestHelper
  let _expected: ISize

  new create(h: TestHelper, expected: ISize) =>
    _h = h
    _expected = expected

  be register_producer(producer: Producer) =>
    None

  be unregister_producer(producer: Producer, credits_returned: ISize) =>
    None

  be credit_request(from: Producer) =>
    None

  be return_credits(credits: ISize) =>
    _h.assert_eq[ISize](_expected, credits)
    _h.complete_action("credits returned")

actor ConsumerThatDoesntGetCreditsReturned is Consumer
  let _h: TestHelper

  new create(h: TestHelper) =>
    _h = h

  be register_producer(producer: Producer) =>
    None

  be unregister_producer(producer: Producer, credits_returned: ISize) =>
    None

  be credit_request(from: Producer) =>
    None

  be return_credits(credits: ISize) =>
    _h.fail()
