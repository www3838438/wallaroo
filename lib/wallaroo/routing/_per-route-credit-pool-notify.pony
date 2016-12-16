class _PerRouteCreditPoolNotify is _CreditPoolNotify
  let _route: RouteLogic ref
  let _cr: _CreditRequester

  new create(r: RouteLogic ref, cr: _CreditRequester) =>
    _route = r
    _cr = cr

  fun ref exhausted(pool: _CreditPool) =>
    _route._credits_exhausted()

  fun ref refresh_needed(pool: _CreditPool) =>
    _cr.request()

  fun ref collected(pool: _CreditPool, amount: ISize) =>
    _route._recoup_credits(amount)

  fun ref overflowed(pool: _CreditPool, amount: ISize) =>
    _route._credits_overflowed(amount)
