require_relative '../../libraries/primitive_ensure_choregraphie'

describe Choregraphie::EnsureChoregraphie do
  RSpec.shared_examples 'protects users' do
    let(:fake_dispatcher) do
      Chef::EventDispatch::DSL.new('our own dispatcher')
    end

    before do
      allow(Chef::EventDispatch::DSL).to receive(:new).and_return(fake_dispatcher)

      # we cheat by stubbing this method because it requires too much of chef environment to be setup to even work
      allow(Choregraphie::Choregraphie).to receive(:ensure_whyrun_supported).and_return(true)
    end
    let(:run_context) do
      double('a chef run context')
    end

    let(:unsafe_choregraphie) do
      Choregraphie::Choregraphie.new('unsafe') do
        on 'another_unrelated_resource[name]'
      end
    end

    let(:safe_choregraphie) do
      Choregraphie::Choregraphie.new('safe') do
        on 'my_resource_to_protect[name]'
      end
    end

    before do
      # in this block we prepare a bit the context in which choregraphie is executed without
      # create a real chef run (which would be to complex)
      # We create a run_context (a real chef object), several resources (including the one that is to protect)
      # and after defining choregraphie objects, we simulate the call of "converge_start" event
      # this is necessary because choregraphie heavily rely on chef events to delay evaluation of some code to
      # the most relevant time

      resource1 = instance_double(Chef::Resource, declared_key: 'my_resource_to_protect[name]')
      resource2 = instance_double(Chef::Resource, declared_key: 'other_resource[name]')
      resource_list = [resource1, resource2]
      allow(run_context).to receive(:resource_collection).and_return(resource_list)

      choregraphie # just make sure choregraphies are defined before we run the event handler
      unsafe_choregraphie
      safe_choregraphie
      # make sure "delayed listing of resources" is executed
      fake_dispatcher.handler.converge_start(run_context)
    end

    it 'must check file if resource is not protected by another choregraphie' do
      expect(Choregraphie::Choregraphie).to receive(:all).and_return(
        [
          choregraphie,
          unsafe_choregraphie
        ],
      )
      expect(File).to receive(:exist?).with('unlock_choregraphie_file').and_return(true)
      choregraphie.before.each { |block| block.call 'my_resource_to_protect[name]' }
    end

    it 'must not check file if resource is protected' do
      expect(Choregraphie::Choregraphie).to receive(:all).and_return(
        [
          choregraphie,
          safe_choregraphie
        ],
      )
      expect(File).to_not receive(:exist?).with('unlock_choregraphie_file')
      choregraphie.before.each { |block| block.call 'my_resource_to_protect[name]' }
    end
  end

  before(:each) do
    allow_any_instance_of(Choregraphie::Choregraphie).to receive(:ruby_block)
  end

  context 'when using static resource list' do
    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        on 'my_resource_to_protect[name]'
        ensure_choregraphie 'unlock_choregraphie_file', period: 0.01
      end
    end
    include_examples 'protects users'

    it 'must clean the file in cleanup' do
      expect(File).to receive(:exist?).and_return(true)
      expect(FileUtils).to receive(:rm).with('unlock_choregraphie_file')
      choregraphie.cleanup.each(&:call)
    end
  end

  context 'when using dynamic resource list' do
    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        on(/my_resource_to_protect\[name\]/)
        ensure_choregraphie 'unlock_choregraphie_file', period: 0.01
      end
    end
    include_examples 'protects users'
  end
end
