use "wallaroo/routing"

class NullRouteLogic is RouteLogic
  fun credits_available(): ISize =>
    0

  fun max_credits(): ISize =>
    0

  fun _credits_initialized() =>
    None

  fun _credits_replenished() =>
    None

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
