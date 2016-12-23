use "ponytest"

use "wallaroo/topology"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    TestCreditPool.make().tests(test)
    TestCreditReceiving.make().tests(test)
    TestMessageSending.make().tests(test)
    TestWatermarking.make().tests(test)
