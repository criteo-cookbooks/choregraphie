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
    'when actions do not work on first try' => 3,
  }.each do |ctxt, fails|
    context ctxt do
      it 'must enter the lock' do
        failing_lock = double('failing_lock')
        expect(failing_lock).to receive(:enter).with(name: "my_node").exactly(fails).times.and_return(false) if fails > 0

        lock = double('lock')
        expect(lock).to receive(:enter).with(name: "my_node").and_return(true)

        expect(Semaphore).to receive(:get_or_create).and_return(*([failing_lock] * fails + [lock]))

        choregraphie.before.each { |block| block.call }
      end

      it 'must exit the lock' do
        failing_lock = double('failing_lock')
        expect(failing_lock).to receive(:exit).with(name: "my_node").exactly(fails).times.and_return(false) if fails > 0
        lock = double('lock')
        expect(lock).to receive(:exit).with(name: "my_node").and_return(true)

        expect(Semaphore).to receive(:get_or_create).and_return(*([failing_lock] * fails + [lock]))

        choregraphie.finish.each { |block| block.call }
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
          concurrency_ratio: 0.5,
        },
        backoff: 0
      )
    end
  end

  context 'when the consul_lock service option is set' do
    it 'must count service instances correctly' do
      expect(Diplomat::Service).to receive(:get).with('test-service', :all, {}).and_return([1,2,3,4,5,6])
      lock = double('lock')
      expect(lock).to receive(:enter).with(name: "my_node").and_return(true)

      expect(Semaphore).to receive(:get_or_create).with('/chef_lock/test', 3, dc: nil).and_return(lock)

      choregraphie_service.before.each { |block| block.call }
    end
  end
end
