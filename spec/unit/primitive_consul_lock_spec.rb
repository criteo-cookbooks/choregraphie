require_relative '../../libraries/primitive_consul_lock'
require 'webmock/rspec'
require 'base64'
require 'diplomat'

describe Choregraphie::ConsulLock do
  let(:choregraphie) do
    Choregraphie::Choregraphie.new('test') do
      consul_lock({ path: '/chef_lock/test', id: 'my_node', concurrency: 1, backoff: 0 })
    end
  end

  Semaphore = Choregraphie::Semaphore

  {
    'when every action works on first try' => 0,
    'when actions do not work on first try' => 3
  }.each do |ctxt, fails|
    context ctxt do
      it 'must enter the lock' do
        failing_lock = double('failing_lock')
        expect(failing_lock).to receive(:enter).with(name: 'my_node').exactly(fails).times.and_return(false) if fails > 0

        lock = double('lock')
        expect(lock).to receive(:enter).with(name: 'my_node').and_return(true)

        expect(Semaphore).to receive(:get_or_create).and_return(*([failing_lock] * fails + [lock]))

        choregraphie.before.each(&:call)
      end

      it 'must exit the lock' do
        failing_lock = double('failing_lock')
        expect(failing_lock).to receive(:exit).with(name: 'my_node').exactly(fails).times.and_return(false) if fails > 0
        lock = double('lock')
        expect(lock).to receive(:exit).with(name: 'my_node').and_return(true)

        expect(Semaphore).to receive(:get_or_create).and_return(*([failing_lock] * fails + [lock]))

        choregraphie.finish.each(&:call)
      end
    end
  end

  let(:choregraphie_service) do
    Choregraphie::Choregraphie.new('test') do
      consul_lock(
        path: '/chef_lock/test',
        id: 'my_node',
        service: {
          name: 'test-service',
          concurrency_ratio: 0.5
        },
        backoff: 0,
      )
    end
  end

  context 'when the consul_lock service option is set' do
    it 'must count service instances correctly' do
      expect(Diplomat::Service).to receive(:get).with('test-service', :all, {}).and_return([1, 2, 3, 4, 5, 6])
      lock = double('lock')
      expect(lock).to receive(:enter).with(name: 'my_node').and_return(true)

      expect(Semaphore).to receive(:get_or_create).with('chef_lock/test', concurrency: 3, dc: nil, token: nil, consul_backup_url: nil).and_return(lock)

      choregraphie_service.before.each(&:call)
    end
  end

  describe 'ensure_latest_policy' do
    let(:choregraphie_policy) do
      Choregraphie::Choregraphie.new('test_policy') do
        consul_lock(path: '/chef_lock/test', id: 'my_node', concurrency: 1, backoff: 0, ensure_latest_policy: true)
      end
    end

    before do
      lock = double('lock')
      allow(lock).to receive(:enter).with(name: 'my_node').and_return(true)
      allow(Semaphore).to receive(:get_or_create).and_return(lock)

      Chef::Config[:policy_name] = 'my_policy'
      Chef::Config[:policy_group] = 'production'
      Chef::Config[:chef_server_url] = 'https://chef.example.com'
    end

    it 'raises OutdatedPolicyError and releases the lock when policy is outdated' do
      node = double('node', policy_revision: 'abc123')
      events = double('events', register: nil)
      allow(Chef).to receive(:run_context).and_return(double('run_context', node: node, events: events))

      enter_lock = double('enter_lock')
      allow(enter_lock).to receive(:enter).with(name: 'my_node').and_return(true)

      exit_lock = double('exit_lock')
      expect(exit_lock).to receive(:exit).with(name: 'my_node').and_return(true)

      allow(Semaphore).to receive(:get_or_create).and_return(enter_lock, exit_lock)

      api = double('api')
      allow(Chef::ServerAPI).to receive(:new).and_return(api)
      allow(api).to receive(:get).and_return({ 'revision_id' => 'def456' })

      expect { choregraphie_policy.before.each(&:call) }
        .to raise_error(Choregraphie::OutdatedPolicyError, /newer revision/)
    end

    it 'proceeds when policy is up to date' do
      node = double('node', policy_revision: 'abc123')
      events = double('events', register: nil)
      allow(Chef).to receive(:run_context).and_return(double('run_context', node: node, events: events))

      api = double('api')
      allow(Chef::ServerAPI).to receive(:new).and_return(api)
      allow(api).to receive(:get).and_return({ 'revision_id' => 'abc123' })

      expect { choregraphie_policy.before.each(&:call) }.not_to raise_error
    end

    it 'skips the check when not explicitly enabled' do
      choregraphie_default = Choregraphie::Choregraphie.new('test_default') do
        consul_lock(path: '/chef_lock/test', id: 'my_node', concurrency: 1, backoff: 0)
      end

      lock = double('lock')
      allow(lock).to receive(:enter).with(name: 'my_node').and_return(true)
      allow(Semaphore).to receive(:get_or_create).and_return(lock)

      expect(Chef::ServerAPI).not_to receive(:new)
      choregraphie_default.before.each(&:call)
    end

    it 'skips the check when node does not use policyfiles' do
      Chef::Config[:policy_name] = nil
      Chef::Config[:policy_group] = nil

      expect(Chef::ServerAPI).not_to receive(:new)
      expect { choregraphie_policy.before.each(&:call) }.not_to raise_error
    end

    it 'continues on network error (fail-open)' do
      api = double('api')
      allow(Chef::ServerAPI).to receive(:new).and_return(api)
      allow(api).to receive(:get).and_raise(Errno::ECONNREFUSED, 'connection refused')

      expect(Chef::Log).to receive(:warn).with(/Failed to check policy freshness/)
      expect { choregraphie_policy.before.each(&:call) }.not_to raise_error
    end

    it 'raises on HTTP errors and releases the lock' do
      node = double('node', policy_revision: 'abc123')
      events = double('events', register: nil)
      allow(Chef).to receive(:run_context).and_return(double('run_context', node: node, events: events))

      enter_lock = double('enter_lock')
      allow(enter_lock).to receive(:enter).with(name: 'my_node').and_return(true)

      exit_lock = double('exit_lock')
      expect(exit_lock).to receive(:exit).with(name: 'my_node').and_return(true)

      allow(Semaphore).to receive(:get_or_create).and_return(enter_lock, exit_lock)

      api = double('api')
      allow(Chef::ServerAPI).to receive(:new).and_return(api)
      allow(api).to receive(:get).and_raise(Net::HTTPClientException.new('404 Not Found', double('response', code: '404')))

      expect { choregraphie_policy.before.each(&:call) }
        .to raise_error(Net::HTTPClientException)
    end
  end
end
