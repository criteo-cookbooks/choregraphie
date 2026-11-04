require_relative '../../libraries/primitive_consul_lock'
require_relative '../../libraries/primitive_consul_rack_lock'
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

      expect(Semaphore).to receive(:get_or_create).with('chef_lock/test', concurrency: 3, dc: nil, token: nil, consul_backup_url: nil, http_addr: nil).and_return(lock)

      choregraphie_service.before.each(&:call)
    end
  end

  describe 'http_addr resolution' do
    let(:node) { Chef::Node.new }
    let(:run_context) { double('run_context', node: node) }

    before { allow(Chef).to receive(:run_context).and_return(run_context) }

    def http_addr_of(options)
      Choregraphie::ConsulLock.new({ path: '/chef_lock/test', id: 'my_node' }.merge(options))
                              .instance_variable_get(:@options)[:http_addr]
    end

    it 'uses the node attribute when http_addr is not given' do
      node.default['choregraphie']['consul_lock']['http_addr'] = 'https://lock.example.com:443'
      expect(http_addr_of({})).to eq('https://lock.example.com:443')
    end

    it 'prefers an explicit http_addr over the node attribute' do
      node.default['choregraphie']['consul_lock']['http_addr'] = 'https://lock.example.com:443'
      expect(http_addr_of(http_addr: 'https://other.example.com')).to eq('https://other.example.com')
    end

    it 'lets an explicit nil http_addr opt out of the node attribute' do
      node.default['choregraphie']['consul_lock']['http_addr'] = 'https://lock.example.com:443'
      expect(http_addr_of(http_addr: nil)).to be_nil
    end

    it 'is nil when the attribute is unset' do
      expect(http_addr_of({})).to be_nil
    end

    it 'is nil outside of a chef run' do
      allow(Chef).to receive(:run_context).and_return(nil)
      expect(http_addr_of({})).to be_nil
    end

    it 'applies to consul_rack_lock' do
      node.default['choregraphie']['consul_lock']['http_addr'] = 'https://lock.example.com:443'
      rack_lock = Choregraphie::ConsulRackLock.new(path: '/chef_lock/test', id: 'my_node', rack: 'rack1')
      expect(rack_lock.instance_variable_get(:@options)[:http_addr]).to eq('https://lock.example.com:443')
    end
  end
end
