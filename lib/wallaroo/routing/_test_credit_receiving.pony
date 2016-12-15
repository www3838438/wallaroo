use "ponytest"

actor TestCreditReceiving is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestNotYetReadyRouteInteractions)
    test(_TestReadyRouteWithoutCreditsInteractions)
    //test(_TestReadyRouteWithCreditsInteractions)

class iso _TestReceiveCredits is UnitTest
  fun name(): String =>
    "credit-receiving/????"

  fun ref apply(h: TestHelper) =>
    None

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
