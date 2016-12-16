use "wallaroo/routing"

class NullTestRouteCallbackHandler is RouteCallbackHandler
  fun ref register(producer: Producer ref, r: RouteLogic tag) =>
    None

  fun shutdown(p: Producer ref) =>
    None

  fun ref credits_initialized(producer: Producer ref) =>
    None

  fun ref credits_replenished(p: Producer ref) =>
    None

  fun ref credits_exhausted(p: Producer ref) =>
    None
