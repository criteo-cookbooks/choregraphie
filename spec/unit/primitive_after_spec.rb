require_relative '../../libraries/primitive_after'

describe Choregraphie::After do
  let(:block) { proc {} }
  let(:choregraphie) do
    Choregraphie::Choregraphie.new('test') do
      after(&block)
    end
  end

  describe 'standard behavior' do
    before do
      # all file manipulation are no-op
      allow(FileUtils).to receive(:touch)
      allow(FileUtils).to receive(:rm)
    end

    context 'when node has been installed long time ago' do
      before do
        allow(File).to receive(:exist?).with(/installed/).and_return(true)
      end

      context 'when a choregraphie starts' do
        it 'must mark its in progress state' do
          expect(FileUtils).to receive(:touch).with(/inprogress/)
          choregraphie.before.each(&:call)
        end
      end

      context 'when a choregraphie is in progress' do
        it 'must call its block' do
          allow(File).to receive(:exist?).with(/inprogress/).and_return(true)
          expect(block).to receive(:call)
          choregraphie.cleanup.each(&:call)
        end
      end

      context 'when no choregraphie is in progress' do
        it 'must not call its block' do
          allow(File).to receive(:exist?).with(/inprogress/).and_return(false)
          expect(block).not_to receive(:call)
          choregraphie.cleanup.each(&:call)
        end
      end
    end

    context 'when node has just been installed' do
      before do
        allow(File).to receive(:exist?).with(/installed/).and_return(false)
      end
      context 'when a choregraphie is in progress' do
        before { allow(File).to receive(:exist?).with(/inprogress/).and_return(true) }
        it 'must call its block' do
          expect(block).to receive(:call)
          choregraphie.cleanup.each(&:call)
        end
        it 'must mark server as "installed"' do
          expect(FileUtils).to receive(:touch).with(/installed/)
          choregraphie.cleanup.each(&:call)
        end
      end

      context 'when no choregraphie is marked in progress' do
        before { allow(File).to receive(:exist?).with(/inprogress/).and_return(false) }
        it 'must call its block' do
          expect(block).to receive(:call)
          choregraphie.cleanup.each(&:call)
        end

        it 'must mark server as "installed"' do
          expect(FileUtils).to receive(:touch).with(/installed/)
          choregraphie.cleanup.each(&:call)
        end
      end
    end
  end

  describe 'invariants' do
    subject { Choregraphie::After.new }
    before { subject.register(choregraphie) }

    describe '.set_in_progress' do
      let(:cache_dir) { Dir.mktmpdir }

      before { Chef::Config[:file_cache_path] = cache_dir }
      after { FileUtils.rm_rf(cache_dir) }

      it 'makes in_progress? change behavior' do
        expect { subject.set_in_progress }.to change { subject.in_progress? }.to(true)
      end
    end

    describe '.set_installed' do
      let(:cache_dir) { Dir.mktmpdir }

      before { Chef::Config[:file_cache_path] = cache_dir }
      after { FileUtils.rm_rf(cache_dir) }

      it 'makes installed? change behavior' do
        expect { subject.set_installed }.to change { subject.installed? }.to(true)
      end
    end
  end
end
