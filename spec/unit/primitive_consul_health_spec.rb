require_relative '../../libraries/primitive_consul_health'
require 'webmock/rspec'
require 'json'

describe Choregraphie::ConsulHealthCheck do
  let(:choregraphie) do
    Choregraphie::Choregraphie.new('test') do
      consul_health_check(
        checkids: ["service:ping"],
        tries: 3,
        delay: 1
      )
    end
  end

  let(:health_check) do
    Choregraphie::ConsulHealthCheck.new(
      checkids: ["service:ping"],
      tries: 3,
      delay: 1
    )
  end

  let(:succeeding_choreg) do
    Choregraphie::Choregraphie.new('test') do
    end
  end

  context 'when the healthcheck is not passing after n times' do
    it 'must count service instances correctly' do
      stub_request(:get, "http://localhost:8500/v1/agent/checks")
        .to_return([
            {
              body: {
                "service:ping" => {
                    CheckID: "service:ping",
                    Name: "Service 'ping' check",
                    Status: "critical"
                }
            }.to_json
          }] * 3)

      expect(Chef::Application).to receive(:fatal!)

      choregraphie.cleanup.each { |block| block.call }
    end
  end

  context 'when the healthcheck is passing ' do

    it 'must count service instances correctly' do
      stub_request(:get, "http://localhost:8500/v1/agent/checks")
        .to_return([
            {body: '{
                "service:ping": {
                    "CheckID": "service:ping",
                    "Name": "Service \'ping\' check",
                    "Status": "passing"
                }
            }
            ', status: 200}
          ])

      expect(health_check.are_checks_passing? 3).to eq true
    end
  end
end
