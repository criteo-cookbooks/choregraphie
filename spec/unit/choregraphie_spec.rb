require_relative '../../libraries/choregraphie'

describe Choregraphie::Choregraphie do
  describe '#before' do

    before(:each) do
      # allow to manipulate the handler at will
      class Chef::EventDispatch::DSL
        attr_accessor :handler
      end
    end

    let(:current_resource) { double('current_resource') }

    let(:provider) {
      double('fake_provider')
    }

    let(:resource) {
      double('fake_resource', {
        to_s: 'fake[resource]',
        provider_for_action: provider,
      })
    }

    let(:dsl) {
      d = Chef::EventDispatch::DSL.new('Test')
      d.handler = double('handler', {
        name: 'handler for test',
      })
      d
    }

    let(:event) {
      # fake chef run plumbery
      evt = Chef::EventDispatch::Dispatcher.new()
      evt.register(dsl.handler)
      evt
    }

    context 'when provider supports why run' do
      before(:each) do
        expect(provider).to receive(:whyrun_supported?).and_return(true)
        expect(Chef::EventDispatch::DSL).to receive(:new).and_return(dsl)

      end

      it 'does not call before block when the resource state is loaded' do

        before_block_called = false

        Choregraphie::Choregraphie.new('test') do
          on 'fake[resource]'
          before do
            before_block_called = true
          end
        end
        # trigger event
        event.resource_current_state_loaded(resource, :run, current_resource)
        expect(before_block_called).to be(false)
      end
      it 'calls before block only on preconverge' do

        before_block_called = false

        Choregraphie::Choregraphie.new('test') do
          on 'fake[resource]'
          before do
            before_block_called = true
          end
        end
        # trigger event
        event.resource_pre_converge(resource, :run, current_resource)
        expect(before_block_called).to be(true)
      end
    end
  end
end
