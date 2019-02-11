require_relative '../../libraries/primitive_consul_health'
require 'webmock/rspec'
require 'json'

describe Choregraphie::ConsulHealthCheck do
  let(:choregraphie) do
    Choregraphie::Choregraphie.new('test') do
      consul_health_check(
        checkids: ['service:ping'],
        tries:    3,
        delay:    0.1,
      )
    end
  end

  context 'when the healthcheck is not passing after n times' do
    it 'must count service instances correctly' do
      stub_request(:get, 'http://localhost:8500/v1/agent/checks')
        .to_return([
          {
            body: {
              'service:ping' => {
                CheckID: 'service:ping',
                Name:    "Service 'ping' check",
                Status:  'critical',
              },
            }.to_json,
          },
        ] * 3,)

      expect { choregraphie.cleanup.each(&:call) }.to raise_error(/Failed to pass Consul checks/)
    end
  end

  context 'when the healthcheck is passing ' do
    it 'must count service instances correctly' do
      stub_request(:get, 'http://localhost:8500/v1/agent/checks').to_timeout.to_timeout
        .to_return(
          body: {
            'service:ping' => {
              CheckID: 'service:ping',
              Name:    "Service 'ping' check",
              Status:  'passing',
            },
          }.to_json,
          status: 200,
      )

      choregraphie.cleanup.each(&:call)
    end
  end

  context %(when the service doesn't exist) do
    it 'must fail with an explicit error' do
      stub_request(:get, 'http://localhost:8500/v1/agent/checks')
        .to_return([
          {
            body: {}.to_json,
          },
        ] * 3,)

      expect { choregraphie.cleanup.each(&:call) }.to raise_error(/Check service:ping is not registered/)
    end
  end
end
