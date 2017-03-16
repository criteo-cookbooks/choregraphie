require_relative '../../libraries/primitive_consul_lock'
require 'webmock/rspec'
require 'base64'

describe Choregraphie::SemaphoreNode do

  SemaphoreNode = Choregraphie::SemaphoreNode

  # erase Chef::Log output
  class Chef::Log
    def self.info(_); end
    def self.warn(_); end
    def self.error(_); end
    def self.debug(_); end
  end

  let(:value) {
    Base64.encode64({version: 1, holders: {another_node:  { 'ts': 12345, 'concurrency': 2 } }}.to_json).gsub(/\n/, '')
  }

  let(:existing_response) {
    {
      status: 200,
      body: <<-EOH
      [{"Value": "#{value}", "ModifyIndex": 1, "CreateIndex": 1, "LockIndex": 0, "Key": "chef_lock/test", "Flags": 0}]
      EOH
    }
  }

  describe '#get_or_create' do
    context 'when the lock already exist' do
      it 'fetch the lock' do
        stub_request(:get, "http://localhost:8500/v1/kv/check-lock/my_lock").
          to_return(existing_response)

        expect(SemaphoreNode.get_or_create('/check-lock/my_lock')).to be_a(Choregraphie::SemaphoreNode)
      end
    end

    context 'when the lock does not exist' do
      it 'fetch the lock' do
        stub_request(:get, "http://localhost:8500/v1/kv/check-lock/my_lock").
          to_return([{status: 404}, existing_response])

        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=0").
          with(:body => "{\"version\":1,\"holders\":{}}").
          to_return( status: 200, body: "true")

        expect(SemaphoreNode.get_or_create('/check-lock/my_lock')).to be_a(Choregraphie::SemaphoreNode)
      end
    end
  end

  let(:lock) do
    value = {version: 1, holders: {another_node: { 'ts': 12345, 'concurrency': 5 }}}.to_json
    SemaphoreNode.new(
      '/check-lock/my_lock',
      { 'Value' => value, 'ModifyIndex' => 42 }
    )
  end
  let(:full_lock) do
    value = {version: 1, holders: {another_node: { 'ts': 12345, 'concurrency': 1 }}}.to_json
    SemaphoreNode.new(
      '/check-lock/my_lock',
      { 'Value' => value, 'ModifyIndex' => 42 }
    )
  end

  describe '.enter' do
    context 'when lock is not full' do
      it 'can enter the lock' do
        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
          with(:body => /"holders":{"another_node":{"ts":12345,"concurrency":5},"myself":{.*}/).
          to_return(status: 200, body: "true")

        expect(lock.enter('myself', 5, {})).to be true
      end

      it 'cannot enter the lock if it has been modified' do
        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
          with(:body => /"holders":{"another_node":{"ts":12345,"concurrency":5},"myself":{.*}/).
          to_return(status: 200, body: "false")
        expect(lock.enter('myself', 5, {})).to be false
      end

      it 'updates concurrency' do
        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
          with(:body => /.*"holders":{"another_node":{"ts":12345,"concurrency":5},"myself":{.*}/).
          to_return(status: 200, body: "true")

        expect(lock.enter('myself', 5, {})).to be true
      end
    end

    context 'when lock is full' do
      it 'cannot take the lock' do
        expect(full_lock.enter('myself', 1, {})).to be false
      end
    end

    context 'when lock is already taken' do
      it 'is re-entrant' do
        expect(full_lock.enter('another_node', 1, {})).to be true
      end
    end
  end

  describe '.exit' do
    it 'return true if it can exit the lock' do
      stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
        with(body: /{"version":1,"holders":{}}/).
        to_return(status: 200, body: "true")

      expect(lock.exit('another_node')).to be true
    end

    it 'return false if it can\'t exit the lock' do
      stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
        with(body: /{"version":1,"holders":{}}/).
        to_return(status: 200, body: "false")

      expect(lock.exit('another_node')).to be false
    end
  end
end

describe Choregraphie::SemaphoreRack do

  SemaphoreRack = Choregraphie::SemaphoreRack

  # erase Chef::Log output
  class Chef::Log
    def self.info(_); end
    def self.warn(_); end
    def self.error(_); end
    def self.debug(_); end
  end

  let(:value) {
    Base64.encode64({version: 1, holders: {another_node:  { 'ts': 12345, 'concurrency': 2, 'rack': 'rack101' } }}.to_json).gsub(/\n/, '')
  }

  let(:existing_response) {
    {
        status: 200,
        body: <<-EOH
      [{"Value": "#{value}", "ModifyIndex": 1, "CreateIndex": 1, "LockIndex": 0, "Key": "chef_lock/test", "Flags": 0}]
        EOH
    }
  }

  describe '#get_or_create' do
    context 'when the lock already exist' do
      it 'fetch the lock' do
        stub_request(:get, "http://localhost:8500/v1/kv/check-lock/my_lock").
            to_return(existing_response)

        expect(SemaphoreRack.get_or_create('/check-lock/my_lock')).to be_a(Choregraphie::SemaphoreRack)
      end
    end

    context 'when the lock does not exist' do
      it 'fetch the lock' do
        stub_request(:get, "http://localhost:8500/v1/kv/check-lock/my_lock").
            to_return([{status: 404}, existing_response])

        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=0").
            with(:body => "{\"version\":1,\"holders\":{}}").
            to_return( status: 200, body: "true")

        expect(SemaphoreRack.get_or_create('/check-lock/my_lock')).to be_a(Choregraphie::SemaphoreRack)
      end
    end
  end

  let(:lock) do
    value = {version: 1, holders: {another_node: { 'ts': 12345, 'concurrency': 5, 'rack': 'rack102' }}}.to_json
    SemaphoreRack.new(
        '/check-lock/my_lock',
        { 'Value' => value, 'ModifyIndex' => 42 }
    )
  end
  let(:full_lock) do
    value = {version: 1, holders: {another_node: { 'ts': 12345, 'concurrency': 1, 'rack': 'rack102' }}}.to_json
    SemaphoreRack.new(
        '/check-lock/my_lock',
        { 'Value' => value, 'ModifyIndex' => 42 }
    )
  end

  describe '.get_rack_list' do
    it 'return one rack' do
      expect(lock.get_rack_list()).to eq ['rack102']
    end

    it 'it return 2 racks for 3 nodes' do
      {
          'node1' => 'rack101',
          'node2' => 'rack102'
      }.each do | node, rack|
      stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
          with(:body => /"holders":{"another_node":{"ts":12345,"concurrency":5,"rack":"rack102"},"#{node}":{.*"rack":"#{rack}".*}/).
          to_return(status: 200, body: "true")

      lock.enter(node, 5, {'rack' => rack})
      end
      expect(lock.get_rack_list()).to eq %w(rack102 rack101)
    end
  end

  describe '.enter' do
    context 'when lock is not full' do
      it 'can enter the lock' do
        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
            with(:body => /"holders":{"another_node":{"ts":12345,"concurrency":5,"rack":"rack102"},"myself":{.*"rack":"rack101".*}/).
            to_return(status: 200, body: "true")

        expect(lock.enter('myself', 5, {'rack' => 'rack101'})).to be true
      end

      it 'cannot enter the lock if it has been modified' do
        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
            with(:body => /"holders":{"another_node":{"ts":12345,"concurrency":5,"rack":"rack102"},"myself":{.*}/).
            to_return(status: 200, body: "false")
        expect(lock.enter('myself', 5, {})).to be false
      end

      it 'updates concurrency' do
        stub_request(:put, "http://localhost:8500/v1/kv/check-lock/my_lock?cas=42").
            with(:body => /.*"holders":{"another_node":{"ts":12345,"concurrency":5,"rack":"rack102"},"myself":{.*}/).
            to_return(status: 200, body: "true")

        expect(lock.enter('myself', 5, {})).to be true
      end
    end

    context 'when lock is full' do
      it 'cannot take the lock' do
        expect(full_lock.enter('myself', 1, {'rack' => 'rack101'})).to be false
      end
    end

    context 'when lock is already taken' do
      it 'is re-entrant' do
        expect(full_lock.enter('another_node', 1, {'rack' => 'rack101'})).to be true
      end
    end
  end
end
