use "ponytest"

actor TestCreditPool is TestList
  """
  Test arounds receiving credits
  """
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestInitialization)
    test(_TestExpend)
    test(_TestUsingAllCreditsTriggersNotification)
    test(_TestRefreshNeededBeforeEmptyingThePool)
    test(_TestCollect)
    test(_TestCollectUpdatesRefreshAt)
    test(_TestCantSurpassMax)
    test(_TestSurpassingMaxTriggersCreditReturn)
    test(_TestUpdateMax)
    test(_TestUpdatingMaxToBelowAvailableOverflows)
    test(_TestUpdatingMaxToBelowAvailableChangesRefreshAt)

class iso _TestInitialization is UnitTest
  """
  Verify that our pool gets initialized correctly
  """
  fun name(): String =>
    "credit-pool/Initialization"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 12)

    h.assert_eq[ISize](12, pool.available())
    h.assert_true(pool.next_refresh() > 0)

class iso _TestExpend is UnitTest
  """
  Verify expending a credit correctly decrements
  """
  fun name(): String =>
    "credit-pool/Expend"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 2)

    h.assert_eq[ISize](2, pool.available())
    pool.expend()
    h.assert_eq[ISize](1, pool.available())

class iso _TestUsingAllCreditsTriggersNotification is UnitTest
  """
  Verify expending to 0 results in the notify getting `exhausted` and
  `refresh_needed` being called called
  """
  fun name(): String =>
    "credit-pool/UsingAllCreditsTriggersNotification"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NotificationReportingCreditPoolNotify(h), 1)

    h.long_test(1_000_000_000)
    h.expect_action("exhausted")
    h.expect_action("refresh_needed")

    h.assert_eq[ISize](1, pool.available())
    pool.expend()
    h.assert_eq[ISize](0, pool.available())

class iso _TestRefreshNeededBeforeEmptyingThePool is UnitTest
  """
  Verify expending 'refresh_at' point triggers `refresh_needed` being called
  on the notify
  """
  fun name(): String =>
    "credit-pool/RefreshNeededBeforeEmptyingThePool"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NotificationReportingCreditPoolNotify(h), 4)

    h.long_test(1_000_000_000)
    h.expect_action("refresh_needed")

    h.assert_eq[ISize](4, pool.available())
    h.assert_eq[ISize](3, pool.next_refresh())
    pool.expend()
    h.assert_true(pool.available() > 0)

class iso _TestCollect is UnitTest
  """
  Verify collecting credits correctly increments
  """
  fun name(): String =>
    "credit-pool/Collect"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 0)

    h.assert_eq[ISize](0, pool.available())
    pool.collect()
    h.assert_eq[ISize](1, pool.available())
    pool.collect(10)
    h.assert_eq[ISize](11, pool.available())

class iso _TestCollectUpdatesRefreshAt is UnitTest
  """
  Verify that refresh_at gets updated after calling collect
  """
  fun name(): String =>
    "credit-pool/CollectUpdatesRefreshAt"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 0)

    h.assert_eq[ISize](0, pool.available())
    h.assert_eq[ISize](0, pool.next_refresh())
    pool.collect(4)
    h.assert_true(pool.available() > 0)
    h.assert_true(pool.next_refresh() > 0)

class iso _TestCantSurpassMax is UnitTest
  """
  Verify that we never increment past the max allowed number of credits
  for the pool.
  """
  fun name(): String =>
    "credit-pool/CantSurpassMax"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NotificationReportingCreditPoolNotify(h), 0, 5)

    h.assert_eq[ISize](0, pool.available())
    pool.collect(10)
    h.assert_eq[ISize](5, pool.available())

class iso _TestSurpassingMaxTriggersCreditReturn is UnitTest
  """
  Verify that is we overflow when collecting credits call `overflowed`
  on the notify with the correct value
  """
  fun name(): String =>
    "credit-pool/SurpassingMaxTriggersCreditReturn"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_OverflowCheckingCreditPoolNotify(h, 45), 0, 5)

    h.long_test(1_000_000_000)
    h.expect_action("overflowed")

    h.assert_eq[ISize](0, pool.available())
    pool.collect(50)

class iso _TestUpdateMax is UnitTest
  """
  Verify that updating the max correctly updates.
  """
  fun name(): String =>
    "credit-pool/UpdateMax"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 0, 5)

    let new_max = ISize(10)
    h.assert_ne[ISize](new_max, pool.max())
    pool.change_max(new_max)
    h.assert_eq[ISize](new_max, pool.max())

class iso _TestUpdatingMaxToBelowAvailableOverflows is UnitTest
  """
  Verify that is we set a new max below currently available credits that
  we overflow.

  For example:

    max is 10
    available is 9
    max is changed to 5
    new available should be 5
    4 credits should overflow
  """
  fun name(): String =>
    "credit-pool/UpdatingMaxToBelowAvailableOverflows"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_OverflowCheckingCreditPoolNotify(h, 4), 0, 10)

    h.long_test(1_000_000_000)
    h.expect_action("overflowed")

    h.assert_eq[ISize](0, pool.available())
    pool.collect(9)
    pool.change_max(5)
    h.assert_eq[ISize](5, pool.available())

class iso _TestUpdatingMaxToBelowAvailableChangesRefreshAt is UnitTest
  """
  Verify that when we set the max below the current available
  and force an update of available that change `refresh_at` value.
  """
  fun name(): String =>
    "credit-pool/UpdatingMaxToBelowAvailableChangesRefreshAt"

  fun apply(h: TestHelper) =>
    let pool = _CreditPool(_NullCreditPoolNotify, 0, 50)

    pool.collect(40)
    let before = pool.next_refresh()
    pool.change_max(5)
    let after = pool.next_refresh()
    h.assert_ne[ISize](before, after)

class _NullCreditPoolNotify is _CreditPoolNotify
  fun ref exhausted(pool: _CreditPool) =>
    None

  fun ref refresh_needed(pool: _CreditPool) =>
    None

  fun ref overflowed(pool: _CreditPool, amount: ISize) =>
    None

class _NotificationReportingCreditPoolNotify is _CreditPoolNotify
  let _h: TestHelper

  new create(h: TestHelper) =>
    _h = h

  fun ref exhausted(pool: _CreditPool) =>
    _h.complete_action("exhausted")

  fun ref refresh_needed(pool: _CreditPool) =>
    _h.complete_action("refresh_needed")

  fun ref overflowed(pool: _CreditPool, amount: ISize) =>
    _h.complete_action("overflowed")

class _OverflowCheckingCreditPoolNotify is _CreditPoolNotify
  let _h: TestHelper
  let _expected: ISize

  new create(h: TestHelper, expected: ISize) =>
    _h = h
    _expected = expected

  fun ref exhausted(pool: _CreditPool) =>
    None

  fun ref refresh_needed(pool: _CreditPool) =>
    None

  fun ref overflowed(pool: _CreditPool, amount: ISize) =>
    _h.assert_eq[ISize](_expected, amount)
    _h.complete_action("overflowed")
