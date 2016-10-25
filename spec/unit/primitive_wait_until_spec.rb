require_relative '../../libraries/primitive_wait_until'

describe Choregraphie::WaitUntil do

  context 'when the condition is a string' do
    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        wait_until 'command', period: 0.001
      end
    end

    it 'must wait for the condition to be true' do
      cmd = double('nothing', run_command: true)
      must_raise = true
      expect(Mixlib::ShellOut).to receive(:new).and_return(cmd)
      expect(cmd).to receive(:error?).twice.and_return(true, false)

      choregraphie.before.each { |block| block.call }
    end
  end

  context 'when the condition is a shellout' do

    let(:shellout) do
      double('shellout', run_command: true, cmd: 'some_command')
    end

    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        wait_until shellout, period: 0.001
      end
    end

    it 'must wait for the condition to be true' do
      allow(Mixlib::ShellOut).to receive(:===).with(shellout).and_return(true)

      must_raise = true
      expect(shellout).to receive(:error?).twice.and_return(true, false)
      choregraphie.before.each { |block| block.call }
    end
  end

  context 'when the condition is a block' do

    let(:choregraphie) do
      should_fail = true
      Choregraphie::Choregraphie.new('test') do
        wait_until period: 0.001 do
          if should_fail
            should_fail = false
            false
          else
            true
          end
        end
      end
    end

    it 'must wait for the condition to be true' do
      choregraphie.before.each { |block| block.call }
    end
  end
end
