class _PerRouteCreditPoolNotify is _CreditPoolNotify
  let _r: CreditRequester
  let _p: Producer ref
  let _c: Consumer

  new create(r: CreditRequester, p: Producer ref, c: Consumer) =>
    _r = r
    _p = p
    _c = c

  fun ref exhausted(pool: _CreditPool) =>
    _p.credits_exhausted()

  fun ref refresh_needed(pool: _CreditPool) =>
    _r.request()

  fun ref collected(pool: _CreditPool, amount: ISize) =>
    _p.recoup_credits(amount)

  fun ref overflowed(pool: _CreditPool, amount: ISize) =>
    _c.return_credits(amount)
