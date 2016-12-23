use "wallaroo/fail"
use "wallaroo/invariant"

trait _CreditReceiver
  fun state(): String
  fun ref preconditions(route: RouteLogic, credits: ISize)
  fun ref action(route: RouteLogic, was_zero: Bool)

class _NotYetReadyRoute is _CreditReceiver
  fun state(): String =>
    "Not Initialized"

  fun ref preconditions(route: RouteLogic, credits: ISize) =>
    ifdef debug then
      Invariant(route.credits_available() == 0)
    end

  fun ref action(route: RouteLogic, was_zero: Bool) =>
    ifdef debug then
      Invariant(was_zero)
    end

    route._credits_initialized()

class _ReadyRoute is _CreditReceiver
  fun state(): String =>
    "Initialized"

  fun ref preconditions(route: RouteLogic, credits: ISize) =>
    ifdef debug then
      Invariant(route.credits_available() <= route.max_credits())
    end

  fun ref action(route: RouteLogic, was_zero: Bool) =>
    if was_zero then
      route._credits_replenished()
    end
