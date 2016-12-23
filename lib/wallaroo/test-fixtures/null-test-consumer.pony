use "wallaroo/routing"

class NullTestConsumer is Consumer
  fun tag register_producer(producer: Producer): Consumer tag =>
    this

  fun tag unregister_producer(producer: Producer, credits_returned: ISize): Consumer tag
   =>
    this

  fun tag credit_request(from: Producer): Consumer tag =>
    this

  fun tag return_credits(credits: ISize): Consumer tag =>
    this
