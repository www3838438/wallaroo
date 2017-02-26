#include "Counter.hpp"
#include "WallarooCppApi/ApiHooks.hpp"
#include "WallarooCppApi/UserHooks.hpp"
#include "WallarooCppApi/Logger.hpp"

#include <vector>
#include <string.h>
#include <iostream>

extern "C"
{
  extern CounterPartitionKey* get_partition_key(size_t idx)
  {
    wallaroo::Logger::getLogger()->warn("Partition Key");
    return new CounterPartitionKey(idx);
  }

  extern CounterPartitionFunction* get_partition_function(size_t idx)
  {
    return new CounterPartitionFunction();
  }

  extern CounterSourceDecoder* get_source_decoder()
  {
    return new CounterSourceDecoder();
  }

  extern CounterSinkEncoder* get_sink_encoder()
  {
    return new CounterSinkEncoder();
  }

  extern SimpleComputation *get_computation()
  {
    return new SimpleComputation();
  }

  extern CounterComputation *get_state_computation()
  {
    return new CounterComputation();
  }

  extern DummyComputation *get_dummy_computation()
  {
    return new DummyComputation();
  }

  extern CounterState *get_state()
  {
    return new CounterState();
  }

  extern wallaroo::StateBuilder *get_counter_state_builder()
  {
    return new CounterStateBuilder();
  }

  extern wallaroo::Serializable *w_user_serializable_deserialize(char *bytes_)
  {
    uint16_t data_type = (((uint16_t)bytes_[0]) << 8) + (uint16_t)bytes_[1];

    switch(data_type)
    {
    case 0:
    {
      Total *total = new Total(0);
      total->deserialize(bytes_ + 2);
      return total;
    }
    case 1:
      return new DummyComputation();
    case 2:
      return new CounterComputation();
    case 3:
    {
      Numbers *numbers = new Numbers();
      numbers->deserialize(bytes_ + 2);
      std::cerr << "xxxx creating Numbers " << numbers << std::endl;
      return numbers;
    }
    case 4:
    {
      return new CounterSinkEncoder();
    }
    case 5:
    {
      return new CounterAddBuilder();
    }
    case 6:
    {
      CounterPartitionKey *cpk = new CounterPartitionKey(0);
      cpk->deserialize(bytes_ + 2);
      return cpk;
    }
    }
    return nullptr;
  }
}

size_t CounterSourceDecoder::header_length()
{
  // std::cerr << "getting header length in the source!" << std::endl;
  return 2;
}

size_t CounterSourceDecoder::payload_length(char *bytes)
{
  // std::cerr << "getting payload length in the source!" << std::endl;
  return ((size_t)(bytes[0]) << 8) + (size_t)(bytes[1]);
}

Numbers *CounterSourceDecoder::decode(char *bytes)
{
  // std::cerr << "decoding in the source!" << std::endl;
  Numbers *n = new Numbers();
  n->decode(bytes);
  return n;
}

Numbers::Numbers():numbers()
{
}

Numbers::Numbers(Numbers& n)
{
  numbers = n.numbers;
}

void Numbers::decode(char *bytes_)
{
  size_t count = ((size_t)(bytes_[0]) << 8) + (size_t)(bytes_[1]);

  for(size_t i = 2; i < ((count * 4) + 2); i += 4)
  {
    uint32_t number = ((uint32_t)(bytes_[i]) << 24) +
      ((uint32_t)(bytes_[i + 1]) << 16) +
      ((uint32_t)(bytes_[i + 2]) << 8) +
      (uint32_t)(bytes_[i + 3]);
    numbers.push_back(number);
  }
}

void Numbers::deserialize (char* bytes)
{
  size_t count = ((size_t)(bytes[0]) << 8) + (size_t)(bytes[1]);

  for(uint32_t i = 2; i < ((count * 4) + 2); i += 4)
  {
    uint32_t number = ((uint32_t)(bytes[i]) << 24) +
      ((uint32_t)(bytes[i + 1]) << 16) +
      ((uint32_t)(bytes[i + 2]) << 8) +
      (uint32_t)(bytes[i + 3]);
    numbers.push_back(number);
  }
}

void Numbers::serialize (char* bytes)
{
  // type
  bytes[0] = 0;
  bytes[1] = 3;

  // count
  int count = numbers.size();
  bytes[2] = (count >> 8) & 0xFF;
  bytes[3] = count & 0xFF;

  for(int i = 0; i < count; i++)
  {
    uint32_t n = numbers[i];
    bytes[4 + (i * 4)] = (n >> 24) & 0xFF;
    bytes[4 + (i * 4) + 1] = (n >> 16) & 0xFF;
    bytes[4 + (i * 4) + 2] = (n >> 8) & 0xFF;
    bytes[4 + (i * 4) + 3] = n & 0xFF;
  }
}

size_t Numbers::serialize_get_size ()
{
  size_t sz = 0;
  sz += 2; // type
  sz += 2; // count
  sz += numbers.size() * 4;
  return sz;
};


uint32_t Numbers::sum()
{
  uint32_t sum = 0;

  for(std::vector<uint32_t>::size_type i = 0; i != numbers.size(); i++) {
    sum += numbers[i];
  }

  return sum;
}

size_t Numbers::encode_get_size()
{
  size_t sz = 0;
  sz += 2; // size
  sz += 2; // count
  sz += numbers.size() * 4;
  return sz;
}

void Numbers::encode(char *bytes)
{
  // size
  size_t sz = 2 + (numbers.size() * 4);

  // size
  bytes[0] = (sz >> 8) & 0xFF;
  bytes[1] = sz & 0xFF;

  // count
  int count = numbers.size();
  bytes[2] = (count >> 8) & 0xFF;
  bytes[3] = count & 0xFF;

  for(int i = 0; i < count; i++)
  {
    uint32_t n = numbers[i];
    bytes[4 + (i * 4)] = (n >> 24) & 0xFF;
    bytes[4 + (i * 4) + 1] = (n >> 16) & 0xFF;
    bytes[4 + (i * 4) + 2] = (n >> 8) & 0xFF;
    bytes[4 + (i * 4) + 3] = n & 0xFF;
  }
}

Total::Total(Total& t)
{
  _total = t._total;
}

Total::Total(uint64_t total): _total(total)
{
}

void Total::deserialize(char *bytes)
{
  _total = (((uint64_t)bytes[0]) << 56) +
    (((uint64_t)bytes[1]) << 48) +
    (((uint64_t)bytes[2]) << 40) +
    (((uint64_t)bytes[3]) << 32) +
    (((uint64_t)bytes[4]) << 24) +
    (((uint64_t)bytes[5]) << 16) +
    (((uint64_t)bytes[6]) << 8) +
    ((uint64_t)bytes[7]);
}

void Total::serialize (char* bytes)
{
  bytes[0] = 0;
  bytes[1] = 1;
  bytes[2] = (char)(_total >> 56) & 0xFF;
  bytes[3] = (char)(_total >> 48) & 0xFF;
  bytes[4] = (char)(_total >> 40) & 0xFF;
  bytes[5] = (char)(_total >> 32) & 0xFF;
  bytes[6] = (char)(_total >> 24) & 0xFF;
  bytes[7] = (char)(_total >> 16) & 0xFF;
  bytes[8] = (char)(_total >> 8) & 0xFF;
  bytes[9] = (char)(_total) & 0xFF;
}

void Total::encode(char *bytes)
{
  bytes[0] = (char)(_total >> 56) & 0xFF;
  bytes[1] = (char)(_total >> 48) & 0xFF;
  bytes[2] = (char)(_total >> 40) & 0xFF;
  bytes[3] = (char)(_total >> 32) & 0xFF;
  bytes[4] = (char)(_total >> 24) & 0xFF;
  bytes[5] = (char)(_total >> 16) & 0xFF;
  bytes[6] = (char)(_total >> 8) & 0xFF;
  bytes[7] = (char)(_total) & 0xFF;
}

size_t CounterSinkEncoder::get_size(wallaroo::Data *data)
{
  Numbers *numbers = static_cast<Numbers *>(data);
  return numbers->encode_get_size();
}

void CounterSinkEncoder::encode(wallaroo::Data *data, char *bytes)
{
  // std::cerr << "encoding in the sink!" << std::endl;
  Numbers *numbers = static_cast<Numbers *>(data);
  numbers->encode(bytes);
}

CounterState::CounterState(): _counter(0)
{
}

void CounterState::add(uint64_t value)
{
  _counter += value;
}

uint64_t CounterState::get_counter()
{
  return _counter;
}

const char *CounterStateBuilder::name()
{
  return "counter state";
}

State *CounterStateBuilder::build()
{
  return get_counter_state();
}

CounterAdd::CounterAdd(uint64_t id): _id(id), _value(0)
{
}

const char *CounterAdd::name()
{
  return "counter add";
}

uint64_t CounterAdd::id()
{
  return _id;
}

void CounterAdd::apply(wallaroo::State *state_)
{
  ((CounterState *)state_)->add(_value);
}

size_t CounterAdd::get_log_entry_size()
{
  return 4;
}

void CounterAdd::to_log_entry(char *bytes_)
{
  bytes_[0] = (_value >> 24) & 0xFF;
  bytes_[1] = (_value >> 16) & 0xFF;
  bytes_[2] = (_value >> 8) & 0xFF;
  bytes_[3] = _value & 0xFF;
}


size_t CounterAdd::get_log_entry_size_header_size()
{
  return 0;
}

bool CounterAdd::read_log_entry(char *bytes_)
{
  _value = ((uint64_t)(bytes_[0]) << 56) +
    ((uint64_t)(bytes_[1]) << 48) +
    ((uint64_t)(bytes_[2]) << 40) +
    ((uint64_t)(bytes_[3]) << 32)+
    ((uint64_t)(bytes_[4]) << 24) +
    ((uint64_t)(bytes_[5]) << 16) +
    ((uint64_t)(bytes_[6]) << 8) +
    (uint64_t)(bytes_[7]);

  return true;
}

void CounterAdd::set_value(uint64_t value_)
{
  _value = value_;
}

wallaroo::StateChange *CounterAddBuilder::build(uint64_t idx_)
{
  return new CounterAdd(idx_);
}

void CounterAddBuilder::deserialize (char* bytes)
{
}

void CounterAddBuilder::serialize (char* bytes)
{
  bytes[0] = 0;
  bytes[1] = 5;
}

size_t CounterAddBuilder::serialize_get_size () {
  return 2;
}

const char *SimpleComputation::name()
{
  return "simple computation";
}

wallaroo::Data *SimpleComputation::compute(wallaroo::Data *input_)
{
  // std::cerr << "inside simple computation!" << std::endl;
  // return new Total(42);
  return new Numbers(*(Numbers *)input_);
}

const char *CounterComputation::name()
{
  return "counter computation";
}

void *CounterComputation::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  // std::cerr << "inside counter computation!" << std::endl;

  uint32_t sum = ((Numbers *) input_)->sum();

  uint64_t old_value = ((CounterState *) state_)->get_counter();

  uint64_t new_total = old_value + sum;
  Total *total = new Total(new_total);

  // std::cout << "new total is " << new_total << " for (" << (((Numbers *) input_)->get_numbers().size() % 2) << ")" << std::endl;

  void *state_change_handle = w_state_change_repository_lookup_by_name(state_change_repository_helper_, state_change_repository_, "counter add");

  CounterAdd *counter_add = (CounterAdd *)w_state_change_get_state_change_object(state_change_repository_helper_, state_change_handle);

  counter_add->set_value(sum);

  return w_stateful_computation_get_return(state_change_repository_helper_, total, state_change_handle);
}

size_t CounterComputation::get_number_of_state_change_builders()
{
  return 1;
}

wallaroo::StateChangeBuilder *CounterComputation::get_state_change_builder(size_t idx_)
{
  return new CounterAddBuilder();
}

const char *DummyComputation::name()
{
  return "dummy computation";
}

void *DummyComputation::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  // std::cerr << "inside dummy computation!" << std::endl;
  Total *total = new Total(*((Total *) input_));

  return w_stateful_computation_get_return(state_change_repository_helper_, total, none);
}

size_t DummyComputation::get_number_of_state_change_builders(){
  return 0;
}

wallaroo::StateChangeBuilder *DummyComputation::get_state_change_builder(size_t idx_)
{
  return nullptr;
}

CounterPartitionKey::CounterPartitionKey(size_t value_): _value(value_)
{
}

uint64_t CounterPartitionKey::hash()
{
  return (uint64_t)get_value();
}

bool CounterPartitionKey::eq(wallaroo::Key *other_)
{
  return get_value() == ((CounterPartitionKey *)other_)->get_value();
}

size_t CounterPartitionKey::get_value()
{
  return _value;
}

void CounterPartitionKey::deserialize(char *bytes_)
{
  _value = ((size_t)(bytes_[0]) << 24) +
    ((size_t)(bytes_[1]) << 16) +
    ((size_t)(bytes_[2]) << 8) +
    (size_t)(bytes_[3]);
}

void CounterPartitionKey::serialize(char* bytes_)
{
  bytes_[0] = 0x00;
  bytes_[1] = 0x06;
  bytes_[2] = (_value >> 24) & 0xFF;
  bytes_[3] = (_value >> 16) & 0xFF;
  bytes_[4] = (_value >> 8) & 0xFF;
  bytes_[5] = _value & 0xFF;
}

void serialize(char *bytes)
{
}

wallaroo::Key *CounterPartitionFunction::partition(wallaroo::Data *data)
{
  Numbers *numbers = (Numbers *)data;
  return new CounterPartitionKey((numbers->get_numbers().size()) % 2);
}