require_relative '../../libraries/primitive_consul_rack_lock'
require 'webmock/rspec'
require 'base64'

describe Choregraphie::SemaphoreByRack do
  SemaphoreByRack = Choregraphie::SemaphoreByRack

  # erase Chef::Log output
  class Chef::Log
    def self.info(_); end

    def self.warn(_); end

    def self.error(_); end

    def self.debug(_); end
  end

  let(:value) do
    Base64.encode64({ version: 1, concurrency: 2, holders: { another_rack: { another_node: 12_345 } } }.to_json).gsub(/\n/, '')
  end

  let(:existing_response) do
    {
      status: 200,
      body:   <<-EOH
      [{"Value": "#{value}", "ModifyIndex": 1, "CreateIndex": 1, "LockIndex": 0, "Key": "chef_lock/test", "Flags": 0}]
      EOH
    }
  end

  describe '#get_or_create' do
    context 'when the lock already exist' do
      it 'fetch the lock' do
        stub_request(:get, 'http://localhost:8500/v1/kv/check-lock/my_lock')
          .to_return(existing_response)

        expect(SemaphoreByRack.get_or_create('check-lock/my_lock', 2)).to be_a(SemaphoreByRack)
      end
    end

    context 'when the lock does not exist' do
      it 'fetch the lock' do
        stub_request(:get, 'http://localhost:8500/v1/kv/check-lock/my_lock')
          .to_return([{ status: 404 }, existing_response])

        stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=0')
          .with(body: '{"version":1,"concurrency":2,"holders":{}}')
          .to_return(status: 200, body: 'true')

        expect(SemaphoreByRack.get_or_create('check-lock/my_lock', 2)).to be_a(SemaphoreByRack)
      end
    end
  end

  let(:lock) do
    value = { version: 1, concurrency: 5, holders: { another_rack: { another_node: 12_345 } } }.to_json
    SemaphoreByRack.new(
      'check-lock/my_lock',
      'Value' => value, 'ModifyIndex' => 42,
    )
  end
  let(:full_lock) do
    value = { version: 1, concurrency: 1, holders: { another_rack: { another_node: 12_345 } } }.to_json
    SemaphoreByRack.new(
      'check-lock/my_lock',
      'Value' => value, 'ModifyIndex' => 42,
    )
  end
  let(:taken_lock) do
    value = { version: 1, concurrency: 5, holders: { my_rack: { myself: 12_345, another_node: 123_456 } } }.to_json
    SemaphoreByRack.new(
      'check-lock/my_lock',
      'Value' => value, 'ModifyIndex' => 42,
    )
  end

  describe '.enter' do
    context 'when lock is not full' do
      it 'can enter the lock' do
        stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=42')
          .with(body: /"holders":{"another_rack":{"another_node":12345},"my_rack":{"myself":".*"}/)
          .to_return(status: 200, body: 'true')

        expect(lock.enter(name: 'my_rack', server: 'myself')).to be true
      end

      it 'cannot enter the lock if it has been modified' do
        stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=42')
          .with(body: /"holders":{"another_rack":{"another_node":12345},"my_rack":{"myself":".*"}/)
          .to_return(status: 200, body: 'false')
        expect(lock.enter(name: 'my_rack', server: 'myself')).to be false
      end

      it 'updates concurrency' do
        stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=42')
          .with(body: /"concurrency":5,"holders":{"another_rack":{"another_node":12345},"my_rack":{"myself":".*"}/)
          .to_return(status: 200, body: 'true')

        expect(lock.enter(name: 'my_rack', server: 'myself')).to be true
      end
    end

    context 'when lock is full' do
      it 'cannot take the lock' do
        expect(full_lock.enter(name: 'my_rack', server: 'myself')).to be false
      end
    end

    context 'when lock is already taken' do
      it 'is re-entrant' do
        expect(full_lock.enter(name: 'another_rack', server: 'another_node')).to be true
      end

      it 'allows any other node to enter' do
        stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=42')
          .with(body: /"holders":{"another_rack":{"another_node":12345,"super_random_name":.*}}/)
          .to_return(status: 200, body: 'true')
        expect(full_lock.enter(name: 'another_rack', server: 'super_random_name')).to be true
      end
    end
  end

  describe '.exit' do
    it 'return true if it can exit the lock' do
      stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=42')
        .with(body: /{"version":1,"concurrency":5,"holders":{}}/)
        .to_return(status: 200, body: 'true')

      expect(lock.exit(name: 'another_rack', server: 'another_node')).to be true
    end

    it %(return false if it can't exit the lock) do
      stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=42')
        .with(body: /{"version":1,"concurrency":5,"holders":{}}/)
        .to_return(status: 200, body: 'false')

      expect(lock.exit(name: 'another_rack', server: 'another_node')).to be false
    end

    it %(does not exit lock for the whole rack if other nodes from the same rack hold it) do
      stub_request(:put, 'http://localhost:8500/v1/kv/check-lock/my_lock?cas=42')
        .with(body: '{"version":1,"concurrency":5,"holders":{"my_rack":{"another_node":123456}}}')
        .to_return(status: 200, body: 'true')

      expect(taken_lock.exit(name: 'my_rack', server: 'myself')).to be true
    end
  end
end
