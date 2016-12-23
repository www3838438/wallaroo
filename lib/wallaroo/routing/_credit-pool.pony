use "wallaroo/invariant"

class _CreditPool
  var _notify: _CreditPoolNotify
  var _max: ISize
  var _available: ISize
  var _refresh_at: ISize

  new create(notify': _CreditPoolNotify = _NullCreditPoolNotify,
    start_at': ISize = 0, max': ISize = ISize.max_value())
  =>
    _notify = notify'
    _available = start_at'
    _max = max'
    _refresh_at = _n(_available)

  fun ref register_notify(notify': _CreditPoolNotify) =>
    ifdef debug then
      Invariant(
        match _notify
        | let x: _NullCreditPoolNotify =>
          true
        else
          false
        end)
    end

    _notify = notify'

  fun available(): ISize =>
    _available

  fun next_refresh(): ISize =>
    _refresh_at

  fun ref collect(number: ISize = 1) =>
    ifdef debug then
      Invariant(number > 0)
    end

    _available = if (_available + number) > _max then
      let overflow = (_available + number) - _max
      _notify.overflowed(this, overflow)
      _notify.collected(this, number - overflow)
      _max
    else
      _notify.collected(this, number)
      _available + number
    end

    _refresh_at = _n(_available)

  fun ref expend() =>
    ifdef debug then
      Invariant(_available > 0)
    end

    _available = _available - 1
    if _available == 0 then
      _notify.exhausted(this)
    end
    if (_available == 0) or
      (_available == _refresh_at)
    then
      _notify.refresh_needed(this)
    end

  fun max(): ISize =>
    _max

  fun ref change_max(n: ISize) =>
    ifdef debug then
      Invariant(n > 0)
    end

    if _available > n then
      let overflowed = _available - n
      _notify.overflowed(this, overflowed)
      _available = n
      _refresh_at = _n(_available)
    end
    _max = n

  fun tag _n(n: ISize): ISize =>
    n - (n >> 2)

trait _CreditPoolNotify
  fun ref exhausted(pool: _CreditPool)
  fun ref refresh_needed(pool: _CreditPool)
  fun ref collected(pool: _CreditPool, amount: ISize)
  fun ref overflowed(pool: _CreditPool, amount: ISize)

class _NullCreditPoolNotify is _CreditPoolNotify
  fun ref exhausted(pool: _CreditPool) =>
    None

  fun ref refresh_needed(pool: _CreditPool) =>
    None

  fun ref collected(pool: _CreditPool, amount: ISize) =>
    None

  fun ref overflowed(pool: _CreditPool, amount: ISize) =>
    None
