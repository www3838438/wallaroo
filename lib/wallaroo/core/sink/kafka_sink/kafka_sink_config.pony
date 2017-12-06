/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "net"
use "options"
use "pony-kafka"
use "pony-kafka/customlogger"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/sink"


primitive KafkaSinkConfigCLIParser
  fun apply(out: OutStream, prefix: String = "kafka_sink"): KafkaConfigCLIParser =>
    KafkaConfigCLIParser(out, KafkaProduceOnly where prefix = prefix)

class val KafkaSinkConfig[Out: Any val] is SinkConfig[Out]
  let _encoder: KafkaSinkEncoder[Out]
  let _ksco: KafkaConfigOptions val
  let _auth: TCPConnectionAuth

  new val create(encoder: KafkaSinkEncoder[Out],
    ksco: KafkaConfigOptions iso,
    auth: TCPConnectionAuth)
  =>
    ksco.client_name = "Wallaroo Kafka Sink " + ksco.topic
    _encoder = encoder
    _ksco = consume ksco
    _auth = auth

  fun apply(): SinkBuilder =>
    KafkaSinkBuilder(TypedKafkaEncoderWrapper[Out](_encoder), _ksco, _auth)

class val KafkaSinkBuilder
  let _encoder_wrapper: KafkaEncoderWrapper
  let _ksco: KafkaConfigOptions val
  let _auth: TCPConnectionAuth

  new val create(encoder_wrapper: KafkaEncoderWrapper,
    ksco: KafkaConfigOptions val,
    auth: TCPConnectionAuth)
  =>
    _encoder_wrapper = encoder_wrapper
    _ksco = ksco
    _auth = auth

  fun apply(reporter: MetricsReporter iso, env: Env): Sink =>
    // create kafka config

    match KafkaConfigFactory(_ksco, env.out)
    | let kc: KafkaConfig val =>
      KafkaSink(_encoder_wrapper, consume reporter, kc, _auth)
    | let ksce: KafkaConfigError =>
      @printf[U32]("%s\n".cstring(), ksce.message().cstring())
      Fail()
      EmptySink
    end
