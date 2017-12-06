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

use "collections"
use "buffered"
use "pony-kafka"
use "net"

use "wallaroo"
use "wallaroo/core/sink"
use "wallaroo/core/sink/kafka_sink"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/kafka_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"
use "wallaroo/core/state"

// these are included because of wallaroo issue #814
use "serialise"
use "wallaroo_labs/mort"

use @set_user_serialization_fns[None](module: Pointer[U8] tag)
use @user_serialization_get_size[USize](o: Pointer[U8] tag)
use @user_serialization[None](o: Pointer[U8] tag, bs: Pointer[U8] tag)
use @user_deserialization[Pointer[U8] val](bs: Pointer[U8] tag)

use @load_module[ModuleP](module_name: CString)

use @application_setup[Pointer[U8] val](module: ModuleP, args: Pointer[U8] val)

use @list_item_count[USize](list: Pointer[U8] val)

use @instantiate_python_class[Pointer[U8] val](klass: Pointer[U8] val)

use @get_application_setup_item[Pointer[U8] val](list: Pointer[U8] val,
  idx: USize)
use @get_application_setup_action[Pointer[U8] val](item: Pointer[U8] val)

use @get_name[Pointer[U8] val](o: Pointer[U8] val)

use @computation_compute[Pointer[U8] val](c: Pointer[U8] val,
  d: Pointer[U8] val, method: Pointer[U8] tag)

use @state_builder_build_state[Pointer[U8] val](sb: Pointer[U8] val)

use @stateful_computation_compute[Pointer[U8] val](c: Pointer[U8] val,
  d: Pointer[U8] val, s: Pointer[U8] val, m: Pointer[U8] tag)

use @source_decoder_header_length[USize](source_decoder: Pointer[U8] val)
use @source_decoder_payload_length[USize](source_decoder: Pointer[U8] val,
  data: Pointer[U8] tag, size: USize)
use @source_decoder_decode[Pointer[U8] val](source_decoder: Pointer[U8] val,
  data: Pointer[U8] tag, size: USize)

use @sink_encoder_encode[Pointer[U8] val](sink_encoder: Pointer[U8] val,
  data: Pointer[U8] val)

use @partition_function_partition_u64[U64](partition_function: Pointer[U8] val,
  data: Pointer[U8] val)

use @partition_function_partition[Pointer[U8] val](
  partition_function: Pointer[U8] val, data: Pointer[U8] val)

use @key_hash[U64](key: Pointer[U8] val)
use @key_eq[I32](key: Pointer[U8] val, other: Pointer[U8] val)

use @py_bool_check[I32](b: Pointer[U8] box)
use @is_py_none[I32](o: Pointer[U8] box)
use @py_incref[None](o: Pointer[U8] box)
use @py_decref[None](o: Pointer[U8] box)
use @py_list_check[I32](b: Pointer[U8] box)

use @Py_Initialize[None]()
use @PyErr_Clear[None]()
use @PyErr_Occurred[Pointer[U8]]()
use @PyErr_print[None]()
use @PyTuple_GetItem[Pointer[U8] val](t: Pointer[U8] val, idx: USize)
use @PyString_Size[USize](str: Pointer[U8] box)
use @PyString_AsString[Pointer[U8]](str: Pointer[U8] box)
use @PyString_FromStringAndSize[Pointer[U8]](str: Pointer[U8] tag, size: USize)
use @PyList_New[Pointer[U8] val](size: USize)
use @PyList_Size[USize](l: Pointer[U8] box)
use @PyList_GetItem[Pointer[U8] val](l: Pointer[U8] box, i: USize)
use @PyList_SetItem[I32](l: Pointer[U8] box, i: USize, item: Pointer[U8] box)
use @PyInt_AsLong[I64](i: Pointer[U8] box)
use @PyObject_HasAttrString[I32](o: Pointer[U8] box, attr: Pointer[U8] tag)

type CString is Pointer[U8] tag

type ModuleP is Pointer[U8] val

class PyData
  var _data: Pointer[U8] val

  new create(data: Pointer[U8] val) =>
    _data = data

  fun obj(): Pointer[U8] val =>
    _data

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_data)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_data, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _data = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_data)

class PyState is State
  var _state: Pointer[U8] val

  new create(state: Pointer[U8] val) =>
    _state = state

  fun obj(): Pointer[U8] val =>
    _state

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_state)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_state, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_state)

class PyStateBuilder
  var _state_builder: Pointer[U8] val

  new create(state_builder: Pointer[U8] val) =>
    _state_builder = state_builder

  fun name(): String =>
    Machida.get_name(_state_builder)

  fun apply(): PyState =>
    PyState(@state_builder_build_state(_state_builder))

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_state_builder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_state_builder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _state_builder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_state_builder)

class PyPartitionFunctionU64
  var _partition_function: Pointer[U8] val

  new create(partition_function: Pointer[U8] val) =>
    _partition_function = partition_function

  fun apply(data: PyData val): U64 =>
    Machida.partition_function_partition_u64(_partition_function, data.obj())

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_partition_function)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_partition_function, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _partition_function = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_partition_function)

class PyKey is (Hashable & Equatable[PyKey])
  var _key: Pointer[U8] val

  new create(key: Pointer[U8] val) =>
    _key = key

  fun obj(): Pointer[U8] val =>
    _key

  fun hash(): U64 =>
    Machida.key_hash(obj())

  fun eq(other: PyKey box): Bool =>
    Machida.key_eq(obj(), other.obj())

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_key)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_key, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _key = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_key)

class PyPartitionFunction
  var _partition_function: Pointer[U8] val

  new create(partition_function: Pointer[U8] val) =>
    _partition_function = partition_function

  fun apply(data: PyData val): PyKey val =>
    recover
      PyKey(Machida.partition_function_partition(_partition_function,
        data.obj()))
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_partition_function)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_partition_function, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _partition_function = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_partition_function)

class PySourceHandler is SourceHandler[PyData val]
  var _source_decoder: Pointer[U8] val

  new create(source_decoder: Pointer[U8] val) =>
    _source_decoder = source_decoder

  fun decode(data: Array[U8] val): PyData val =>
    recover
      PyData(Machida.source_decoder_decode(_source_decoder, data.cpointer(),
        data.size()))
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_source_decoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_source_decoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _source_decoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_source_decoder)

class PyFramedSourceHandler is FramedSourceHandler[PyData val]
  var _source_decoder: Pointer[U8] val
  let _header_length: USize

  new create(source_decoder: Pointer[U8] val) ? =>
    _source_decoder = source_decoder
    let hl = Machida.framed_source_decoder_header_length(_source_decoder)
    if (Machida.err_occurred()) or (hl == 0) then
      @printf[U32]("ERROR: _header_length %d is invalid\n".cstring(), hl)
      error
    else
      _header_length = hl
    end

  fun header_length(): USize =>
    _header_length

  fun payload_length(data: Array[U8] iso): USize =>
    Machida.framed_source_decoder_payload_length(_source_decoder, data.cpointer(),
      data.size())

  fun decode(data: Array[U8] val): PyData val =>
    recover
      PyData(Machida.source_decoder_decode(_source_decoder, data.cpointer(),
        data.size()))
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_source_decoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_source_decoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _source_decoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_source_decoder)

class PyComputationBuilder
  var _computation_class: Pointer[U8] val

  new create(computation_class: Pointer[U8] val) =>
    _computation_class = computation_class

  fun apply(): PyComputation iso^ =>
    recover
      PyComputation(@instantiate_python_class(_computation_class))
    end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_computation_class)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_computation_class, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation_class = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_computation_class)

class PyComputation is Computation[PyData val, PyData val]
  var _computation: Pointer[U8] val
  let _name: String
  let _is_multi: Bool

  new create(computation: Pointer[U8] val) =>
    _computation = computation
    _name = Machida.get_name(_computation)
    _is_multi = Machida.implements_compute_multi(_computation)

  fun apply(input: PyData val): (PyData val | Array[PyData val] val |None) =>
    let r: Pointer[U8] val =
      Machida.computation_compute(_computation, input.obj(), _is_multi)

    if not r.is_null() then
      Machida.process_computation_results(r, _is_multi)
    else
      None
    end

  fun name(): String =>
    _name

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_computation)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_computation, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_computation)

class PyStateComputation is StateComputation[PyData val, PyData val, PyState]
  var _computation: Pointer[U8] val
  let _name: String
  let _is_multi: Bool

  new create(computation: Pointer[U8] val) =>
    _computation = computation
    _name = Machida.get_name(_computation)
    _is_multi = Machida.implements_compute_multi(_computation)

  fun apply(input: PyData val,
    sc_repo: StateChangeRepository[PyState], state: PyState):
    ((PyData val | Array[PyData val] val | None), (None | DirectStateChange))
  =>
    (let data, let persist) =
      Machida.stateful_computation_compute(_computation, input.obj(),
        state.obj(), _is_multi)

    let d = recover if Machida.is_py_none(data) then
        Machida.dec_ref(data)
        None
      else
        Machida.process_computation_results(data, _is_multi)
      end
    end

    let p = if Machida.bool_check(persist) then
      DirectStateChange
    else
      None
    end
    (d, p)

  fun name(): String =>
    _name

  fun state_change_builders(): Array[StateChangeBuilder[PyState]] val =>
    recover val Array[StateChangeBuilder[PyState] val] end

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_computation)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_computation, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _computation = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_computation)

class PyTCPEncoder is TCPSinkEncoder[PyData val]
  var _sink_encoder: Pointer[U8] val

  new create(sink_encoder: Pointer[U8] val) =>
    _sink_encoder = sink_encoder

  fun apply(data: PyData val, wb: Writer): Array[ByteSeq] val =>
    let byte_buffer = Machida.sink_encoder_encode(_sink_encoder, data.obj())
    if not byte_buffer.is_null() and not Machida.is_py_none(byte_buffer) then
      let arr = recover val
        // create a temporary Array[U8] wrapper for the C array, then clone it
        Array[U8].from_cpointer(@PyString_AsString(byte_buffer),
          @PyString_Size(byte_buffer)).clone()
      end
      Machida.dec_ref(byte_buffer)
      wb.write(arr)
    end
    wb.done()

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_sink_encoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_sink_encoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink_encoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_sink_encoder)

class PyKafkaEncoder is KafkaSinkEncoder[PyData val]
  var _sink_encoder: Pointer[U8] val

  new create(sink_encoder: Pointer[U8] val) =>
    _sink_encoder = sink_encoder

  fun apply(data: PyData val, wb: Writer):
    (Array[ByteSeq] val, (Array[ByteSeq] val | None))
  =>
    let out_and_key = Machida.sink_encoder_encode(_sink_encoder, data.obj())
    // `out_and_key` is a tuple of `(out, key)`, where `out` is a
    // string and key is `None` or a string.
    let out_p = @PyTuple_GetItem(out_and_key, 0)
    let key_p = @PyTuple_GetItem(out_and_key, 1)

    let out = wb.>write(recover val
        // create a temporary Array[U8] wrapper for the C array, then clone it
        Array[U8].from_cpointer(@PyString_AsString(out_p),
          @PyString_Size(out_p)).clone()
      end).done()

    let key = if Machida.is_py_none(key_p) then
        None
      else
        wb.>write(recover
          Array[U8].from_cpointer(@PyString_AsString(out_p),
            @PyString_Size(out_p)).clone()
          end).done()
      end

    Machida.dec_ref(out_and_key)

    (consume out, consume key)

  fun _serialise_space(): USize =>
    Machida.user_serialization_get_size(_sink_encoder)

  fun _serialise(bytes: Pointer[U8] tag) =>
    Machida.user_serialization(_sink_encoder, bytes)

  fun ref _deserialise(bytes: Pointer[U8] tag) =>
    _sink_encoder = recover Machida.user_deserialization(bytes) end

  fun _final() =>
    Machida.dec_ref(_sink_encoder)

primitive Machida
  fun print_errors(): Bool =>
    if err_occurred() then
      @PyErr_Print[None]()
      true
    else
      false
    end

  fun err_occurred(): Bool =>
    let er = @PyErr_Occurred[Pointer[U8]]()
    if not er.is_null() then
      true
    else
      false
    end

  fun start_python() =>
    @Py_Initialize()

  fun load_module(module_name: String): ModuleP ? =>
    let r = @load_module(module_name.cstring())
    if print_errors() then
      error
    end
    r

  fun application_setup(module: ModuleP, args: Array[String] val):
    Pointer[U8] val ?
  =>
    let pyargs = Machida.pony_array_string_to_py_list_string(args)
    let r = @application_setup(module, pyargs)
    if print_errors() then
      error
    end
    r

  fun apply_application_setup(application_setup_data: Pointer[U8] val,
    env: Env):
    Application ?
  =>
    let application_setup_item_count = @list_item_count(application_setup_data)

    var app: (None | Application) = None

    for idx in Range(0, application_setup_item_count) do
      let item = @get_application_setup_item(application_setup_data, idx)
      let action_p = @get_application_setup_action(item)
      let action = String.copy_cstring(action_p)
      if action == "name" then
        let name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 1)))
        end
        app = Application(name)
        break
      end
    end

    var source_idx: USize = 0
    var sink_idx: USize = 0

    var latest: (Application | PipelineBuilder[PyData val, PyData val,
      PyData val]) = (app as Application)

    for idx in Range(0, application_setup_item_count) do
      let item = @get_application_setup_item(application_setup_data, idx)
      let action_p = @get_application_setup_action(item)
      let action = String.copy_cstring(action_p)
      match action
      | "new_pipeline" =>
        let name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 1)))
        end

        let source_config = recover val
          let sct = @PyTuple_GetItem(item, 2)
          _SourceConfig.from_tuple(sct, env)?
        end

        latest = (latest as Application).new_pipeline[PyData val, PyData val](
          name,
          source_config)
        source_idx = source_idx + 1
      | "to" =>
        let computation_class = @PyTuple_GetItem(item, 1)
        Machida.inc_ref(computation_class)
        let builder = recover val PyComputationBuilder(computation_class) end
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to[PyData val](builder)
      | "to_parallel" =>
        let computation_class = @PyTuple_GetItem(item, 1)
        Machida.inc_ref(computation_class)
        let builder = recover val PyComputationBuilder(computation_class) end
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_parallel[PyData val](builder)
      | "to_stateful" =>
        let state_computationp = @PyTuple_GetItem(item, 1)
        Machida.inc_ref(state_computationp)
        let state_computation = recover val
          PyStateComputation(state_computationp)
        end

        let state_builderp = @PyTuple_GetItem(item, 2)
        Machida.inc_ref(state_builderp)
        let state_builder = recover val
          PyStateBuilder(state_builderp)
        end

        let state_name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 3)))
        end
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_stateful[PyData val, PyState](state_computation,
          state_builder, state_name)
      | "to_state_partition_u64" =>
        let state_computationp = @PyTuple_GetItem(item, 1)
        Machida.inc_ref(state_computationp)
        let state_computation = recover val
          PyStateComputation(state_computationp)
        end

        let state_builderp = @PyTuple_GetItem(item, 2)
        Machida.inc_ref(state_builderp)
        let state_builder = recover val
          PyStateBuilder(state_builderp)
        end

        let state_name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 3)))
        end

        let partition_functionp = @PyTuple_GetItem(item, 4)
        Machida.inc_ref(partition_functionp)
        let partition_function = recover val
          PyPartitionFunctionU64(partition_functionp)
        end

        let partition_values = Machida.py_list_int_to_pony_array_u64(
          @PyTuple_GetItem(item, 5))

        let partition = Partition[PyData val, U64](partition_function,
          partition_values)
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_state_partition[PyData val, U64, PyData val, PyState](
          state_computation, state_builder, state_name, partition)
      | "to_state_partition" =>
        let state_computationp = @PyTuple_GetItem(item, 1)
        Machida.inc_ref(state_computationp)
        let state_computation = recover val
          PyStateComputation(state_computationp)
        end

        let state_builderp = @PyTuple_GetItem(item, 2)
        Machida.inc_ref(state_builderp)
        let state_builder = recover val
          PyStateBuilder(state_builderp)
        end

        let state_name = recover val
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(item, 3)))
        end

        let partition_functionp = @PyTuple_GetItem(item, 4)
        Machida.inc_ref(partition_functionp)
        let partition_function = recover val
          PyPartitionFunction(partition_functionp)
        end

        let partition_values = Machida.py_list_int_to_pony_array_pykey(
          @PyTuple_GetItem(item, 5))

        let partition = Partition[PyData val, PyKey val](partition_function,
          partition_values)
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_state_partition[PyData val, PyKey val, PyData val, PyState](
          state_computation, state_builder, state_name, partition)
      | "to_sink" =>
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.to_sink(
          _SinkConfig.from_tuple(@PyTuple_GetItem(item, 1), env)?)
        sink_idx = sink_idx + 1
        latest
      | "done" =>
        let pb = (latest as PipelineBuilder[PyData val, PyData val, PyData val])
        latest = pb.done()
        latest
      end
    end

    Machida.dec_ref(application_setup_data)
    app as Application

  fun framed_source_decoder_header_length(source_decoder: Pointer[U8] val): USize =>
    @PyErr_Clear[None]()
    let r = @source_decoder_header_length(source_decoder)
    print_errors()
    if (r >= 1) and (r <= 8) then
      r
    else
      @printf[U32]("ERROR: header_length() method returned invalid size\n".cstring())
      4
    end

  fun framed_source_decoder_payload_length(source_decoder: Pointer[U8] val,
    data: Pointer[U8] tag, size: USize): USize
  =>
    @PyErr_Clear[None]()
    let r = @source_decoder_payload_length(source_decoder, data, size)
    if err_occurred() then
      print_errors()
      4
    else
      r
    end

  fun source_decoder_decode(source_decoder: Pointer[U8] val,
    data: Pointer[U8] tag, size: USize): Pointer[U8] val
  =>
    let r = @source_decoder_decode(source_decoder, data, size)
    print_errors()
    r

  fun sink_encoder_encode(sink_encoder: Pointer[U8] val, data: Pointer[U8] val):
    Pointer[U8] val
  =>
    let r = @sink_encoder_encode(sink_encoder, data)
    print_errors()
    r

  fun computation_compute(computation: Pointer[U8] val, data: Pointer[U8] val,
    multi: Bool): Pointer[U8] val
  =>
    let method = if multi then "compute_multi" else "compute" end
    let r = @computation_compute(computation, data, method.cstring())
    print_errors()
    r

  fun stateful_computation_compute(computation: Pointer[U8] val,
    data: Pointer[U8] val, state: Pointer[U8] val, multi: Bool):
  (Pointer[U8] val, Pointer[U8] val)
  =>
    let method = if multi then "compute_multi" else "compute" end
    let r =
      @stateful_computation_compute(computation, data, state, method.cstring())
    print_errors()
    let msg = @PyTuple_GetItem(r, 0)
    let persist = @PyTuple_GetItem(r, 1)

    inc_ref(msg)
    inc_ref(persist)

    let rt = (msg, persist)

    dec_ref(r)

    rt

  fun partition_function_partition_u64(partition_function: Pointer[U8] val,
    data: Pointer[U8] val): U64
  =>
    let r = @partition_function_partition_u64(partition_function, data)
    print_errors()
    r

  fun py_list_int_to_pony_array_u64(py_array: Pointer[U8] val):
    Array[U64] val
  =>
    let size = @PyList_Size(py_array)
    let arr = recover iso Array[U64](size) end

    for i in Range(0, size) do
      let obj = @PyList_GetItem(py_array, i)
      let v = @PyInt_AsLong(obj)
      arr.push(v.u64())
    end

    consume arr

  fun key_hash(key: Pointer[U8] val): U64 =>
    let r = @key_hash(key)
    print_errors()
    r

  fun key_eq(key: Pointer[U8] val, other: Pointer[U8] val): Bool =>
    let r = not (@key_eq(key, other) == 0)
    print_errors()
    r

  fun partition_function_partition(partition_function: Pointer[U8] val,
    data: Pointer[U8] val): Pointer[U8] val
  =>
    let r = @partition_function_partition(partition_function, data)
    print_errors()
    r

  fun py_list_int_to_pony_array_pykey(py_array: Pointer[U8] val):
    Array[PyKey val] val
  =>
    let size = @PyList_Size(py_array)
    let arr = recover iso Array[PyKey val](size) end

    for i in Range(0, size) do
      let obj = @PyList_GetItem(py_array, i)
      Machida.inc_ref(obj)
      arr.push(recover val PyKey(obj) end)
    end

    consume arr

  fun py_list_int_to_pony_array_pydata(py_array: Pointer[U8] val):
    Array[PyData val] val
  =>
    let size = @PyList_Size(py_array)
    let arr = recover iso Array[PyData val](size) end

    for i in Range(0, size) do
      let obj = @PyList_GetItem(py_array, i)
      Machida.inc_ref(obj)
      arr.push(recover val PyData(obj) end)
    end

    consume arr

  fun pony_array_string_to_py_list_string(args: Array[String] val):
    Pointer[U8] val
  =>
    let l = @PyList_New(args.size())
    for (i, v) in args.pairs() do
      @PyList_SetItem(l, i, @PyString_FromStringAndSize(v.cstring(), v.size()))
    end
    l

  fun get_name(o: Pointer[U8] val): String =>
    let ps = @get_name(o)
    recover
      if not ps.is_null() then
        let ret = String.copy_cstring(@PyString_AsString(ps))
        dec_ref(ps)
	ret
      else
        "undefined-name"
      end
    end

  fun set_user_serialization_fns(m: Pointer[U8] val) =>
    @set_user_serialization_fns(m)

  fun user_serialization_get_size(o: Pointer[U8] tag): USize =>
    let r = @user_serialization_get_size(o)
    if (print_errors()) then
      @printf[U32]("Serialization failed".cstring())
    end
    r

  fun user_serialization(o: Pointer[U8] tag, bs: Pointer[U8] tag) =>
    @user_serialization(o, bs)
    if (print_errors()) then
      @printf[U32]("Serialization failed".cstring())
    end

  fun user_deserialization(bs: Pointer[U8] tag): Pointer[U8] val =>
    let r = @user_deserialization(bs)
    if (print_errors()) then
      @printf[U32]("Deserialization failed".cstring())
    end
    r

  fun bool_check(b: Pointer[U8] val): Bool =>
    not (@py_bool_check(b) == 0)

  fun is_py_none(o: Pointer[U8] box): Bool =>
    not (@is_py_none(o) == 0)

  fun inc_ref(o: Pointer[U8] box) =>
    @py_incref(o)

  fun dec_ref(o: Pointer[U8] box) =>
    @py_decref(o)

  fun process_computation_results(data: Pointer[U8] val, multi: Bool):
    (PyData val | Array[PyData val] val)
  =>
    if not multi then
      recover val PyData(data) end
    else
      if @py_list_check(data) == 1 then
        let out = Machida.py_list_int_to_pony_array_pydata(data)
        Machida.dec_ref(data)
        out
      else
        @printf[U32]("compute_multi must return a list\n".cstring())
        Fail()
        recover val Array[PyData val] end
      end
    end

  fun implements_compute_multi(o: Pointer[U8] box): Bool =>
    implements_method(o, "compute_multi")

  fun implements_method(o: Pointer[U8] box, method: String): Bool =>
    @PyObject_HasAttrString(o, method.cstring()) == 1

primitive _SourceConfig
  fun from_tuple(source_config_tuple: Pointer[U8] val, env: Env):
    SourceConfig[PyData val] ?
  =>
    let name = recover val
      String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(source_config_tuple, 0)))
    end

    match name
    | "tcp" =>
      let host = recover val
        String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(source_config_tuple, 1)))
      end

      let port = recover val
        String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(source_config_tuple, 2)))
      end

      let decoder = recover val
        let d = @PyTuple_GetItem(source_config_tuple, 3)
        Machida.inc_ref(d)
        PyFramedSourceHandler(d)?
      end

      TCPSourceConfig[PyData val](decoder, host, port)
    | "kafka" =>
      let ksco = _kafka_config_options(source_config_tuple)

      let decoder = recover val
        let d = @PyTuple_GetItem(source_config_tuple, 4)
        Machida.inc_ref(d)
        PySourceHandler(d)
      end

      KafkaSourceConfig[PyData val](ksco, (env.root as TCPConnectionAuth), decoder)
    else
      error
    end

  fun _kafka_config_options(source_config_tuple: Pointer[U8] val): KafkaSourceConfigOptions val =>
    let topic = recover val
      String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(source_config_tuple, 1)))
    end

    let brokers_list = @PyTuple_GetItem(source_config_tuple, 2)

    let brokers = recover val
      let num_brokers = @PyList_Size(brokers_list)
      let brokers' = Array[(String, I32)](num_brokers)

      for i in Range(0, num_brokers) do
        let broker = @PyList_GetItem(brokers_list, i)
        let host = recover val String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(broker, 0))) end
        let port = try
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(broker, 1))).i32()?
        else
          9092
        end
        brokers'.push((host, port))
      end
      brokers'
    end

    let log_level = recover val
      String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(source_config_tuple, 3)))
    end

    KafkaSourceConfigOptions(topic, brokers, log_level)

primitive _SinkConfig
  fun from_tuple(sink_config_tuple: Pointer[U8] val, env: Env):
    SinkConfig[PyData val] ?
  =>
    let name = recover val
      String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(sink_config_tuple, 0)))
    end

    match name
    | "tcp" =>
      let host = recover val
        String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(sink_config_tuple, 1)))
      end

      let port = recover val
        String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(sink_config_tuple, 2)))
      end

      let encoderp = @PyTuple_GetItem(sink_config_tuple, 3)
      Machida.inc_ref(encoderp)
      let encoder = recover val
        PyTCPEncoder(encoderp)
      end

      TCPSinkConfig[PyData val](encoder, host, port)
    | "kafka" =>
      let ksco = _kafka_config_options(sink_config_tuple)

      let encoderp = @PyTuple_GetItem(sink_config_tuple, 6)
      Machida.inc_ref(encoderp)
      let encoder = recover val
        PyKafkaEncoder(encoderp)
      end

      KafkaSinkConfig[PyData val](encoder, ksco, (env.root as TCPConnectionAuth))
    else
      error
    end

  fun _kafka_config_options(source_config_tuple: Pointer[U8] val): KafkaSinkConfigOptions val =>
    let topic = recover val
      String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(source_config_tuple, 1)))
    end

    let brokers_list = @PyTuple_GetItem(source_config_tuple, 2)

    let brokers = recover val
      let num_brokers = @PyList_Size(brokers_list)
      let brokers' = Array[(String, I32)](num_brokers)

      for i in Range(0, num_brokers) do
        let broker = @PyList_GetItem(brokers_list, i)
        let host = recover val String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(broker, 0))) end
        let port = try
          String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(broker, 1))).i32()?
        else
          9092
        end
        brokers'.push((host, port))
      end
      brokers'
    end

    let log_level = recover val
      String.copy_cstring(@PyString_AsString(@PyTuple_GetItem(source_config_tuple, 3)))
    end

    let max_produce_buffer_ms = @PyInt_AsLong(@PyTuple_GetItem(source_config_tuple, 4)).u64()

    let max_message_size = @PyInt_AsLong(@PyTuple_GetItem(source_config_tuple, 5)).i32()

    KafkaSinkConfigOptions(topic, brokers, log_level, max_produce_buffer_ms, max_message_size)
