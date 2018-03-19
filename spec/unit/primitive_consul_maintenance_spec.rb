require_relative '../../libraries/primitive_consul_maintenance'
require 'diplomat'

describe Choregraphie::ConsulMaintenance do

  context 'When using consul_maintenance on node' do
    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        consul_maintenance reason: 'Testing'
      end
    end

    it 'Must enable maintenance mode before' do
      stub_request(:get, "localhost:8500/v1/agent/checks").to_return(status: 200, body: "{}")
      expect(Diplomat::Maintenance).to receive(:enable).with(true, 'Testing').and_return(true)
      choregraphie.before.each { |block| block.call }
    end

    it 'Must disable maintenance mode in cleanup' do
      stub_request(:get, "localhost:8500/v1/agent/checks")
        .to_return(status: 200, body: '{"_node_maintenance": {"CheckID": "_node_maintenance", "Status": "critical", "Notes": "Testing"}}')
      expect(Diplomat::Maintenance).to receive(:enable).with(false, 'Testing').and_return(true)
      choregraphie.cleanup.each { |block| block.call }
    end

    it 'Must not disable maintenance mode in cleanup if enabled for other reasons' do
      stub_request(:get, "localhost:8500/v1/agent/checks")
        .to_return(status: 200, body: '{"_node_maintenance": {"CheckID": "_node_maintenance", "Status": "critical", "Notes": "for reasons..."}}')
      expect(Diplomat::Maintenance).to_not receive(:enable)
      choregraphie.cleanup.each { |block| block.call }
    end

    #it 'Must not disable maintenance mode in cleanup if not enabled' do
    #  stub_request(:get, "localhost:8500/v1/agent/checks").to_return(status: 200, body: "{}")
    #  expect(Diplomat::Maintenance).to_not receive(:enable)
    #  choregraphie.cleanup.each { |block| block.call }
    #end

  end

  context 'When using consul_maintenance on service' do
    let(:service_id) {'service_test'}
    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        consul_maintenance service_id: service_id, reason: 'Testing'
      end
    end

    it 'Must enable maintenance mode before' do
      stub_request(:get, 'localhost:8500/v1/agent/checks').to_return(status: 200, body: '{}')
      expect(Diplomat::Service).to receive(:maintenance).with(service_id, {'enable': true, 'reason': 'Testing'}).and_return(true)
      choregraphie.before.each {|block| block.call}
    end

    it 'Must disable maintenance mode in cleanup' do
      stub_request(:get, 'localhost:8500/v1/agent/checks')
          .to_return(status: 200, body: "{\"_service_maintenance:#{service_id}\": {\"Node\": \"test_node\",
\"CheckID\": \"_service_maintenance:#{service_id}\",\"Name\": \"Service Maintenance Mode\",\"Status\": \"critical\",
\"Notes\": \"Testing\",\"Output\": \"\",\"ServiceID\": \"#{service_id}\",\"ServiceName\": \"#{service_id}\",\"ServiceTags\": [],
\"Definition\": {},\"CreateIndex\": 0,\"ModifyIndex\": 0}}")
      expect(Diplomat::Service).to receive(:maintenance).with(service_id, {'enable': false, 'reason': 'Testing'}).and_return(true)
      choregraphie.cleanup.each {|block| block.call}
    end

    it 'Must not disable maintenance mode in cleanup if enabled for other reasons' do
      stub_request(:get, 'localhost:8500/v1/agent/checks')
          .to_return(status: 200, body: "{\"_service_maintenance:#{service_id}\": {\"Node\": \"test_node\",
\"CheckID\": \"_service_maintenance:#{service_id}\",\"Name\": \"Service Maintenance Mode\",\"Status\": \"critical\",
\"Notes\": \"Some other reason...\",\"Output\": \"\",\"ServiceID\": \"#{service_id}\",\"ServiceName\": \"#{service_id}\",\"ServiceTags\": [],
\"Definition\": {},\"CreateIndex\": 0,\"ModifyIndex\": 0}}")
      expect(Diplomat::Service).to_not receive(:maintenance)
      choregraphie.cleanup.each {|block| block.call}
    end
  end
end
