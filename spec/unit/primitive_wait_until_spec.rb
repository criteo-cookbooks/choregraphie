require_relative '../../libraries/primitive_wait_until'

describe Choregraphie::WaitUntil do

  let(:environment) do
    double('env').tap do |dble|
      expect(dble).to receive(:[]=).with('RESOURCE_NAME', kind_of(String)).at_least(:once)
    end
  end

  def mock_env(cmd)
    expect(cmd).to receive(:environment).and_return(environment).at_least(:once)
  end

  context 'when the condition is a string at before' do
    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        wait_until 'command', period: 0.001
      end
    end

    it 'must wait for the condition to be true' do
      cmd = double('nothing', run_command: true)
      must_raise = true
      expect(Mixlib::ShellOut).to receive(:new).and_return(cmd)
      mock_env(cmd)
      expect(cmd).to receive(:error?).twice.and_return(true, false)

      choregraphie.before.each { |block| block.call('a resource name') }
    end
  end

  context 'when the condition is a string at cleanup' do
    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        wait_until 'command', period: 0.001,when: 'cleanup'
      end
    end

    it 'must wait for the condition to be true' do
      cmd = double('nothing', run_command: true)
      must_raise = true
      expect(Mixlib::ShellOut).to receive(:new).and_return(cmd)
      mock_env(cmd)
      expect(cmd).to receive(:error?).twice.and_return(true, false)

      choregraphie.cleanup.each { |block| block.call('a resource name') }
    end
  end
  context 'when the condition is a shellout' do

    let(:shellout) do
      double('shellout', run_command: true, cmd: 'some_command').tap do |dble|
        mock_env(dble)
      end
    end

    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        wait_until shellout, period: 0.001
      end
    end

    it 'must wait for the condition to be true at before' do
      allow(Mixlib::ShellOut).to receive(:===).with(shellout).and_return(true)

      must_raise = true
      expect(shellout).to receive(:error?).twice.and_return(true, false)
      choregraphie.before.each { |block| block.call('a resource name') }
    end
  end

  context 'when the condition is a shellout at cleanup' do

    let(:shellout) do
      double('shellout', run_command: true, cmd: 'some_command').tap do |dble|
        mock_env(dble)
      end
    end

    let(:choregraphie) do
      Choregraphie::Choregraphie.new('test') do
        wait_until shellout, period: 0.001, when: 'cleanup'
      end
    end

    it 'must wait for the condition to be true at cleanup' do
      allow(Mixlib::ShellOut).to receive(:===).with(shellout).and_return(true)

      must_raise = true
      expect(shellout).to receive(:error?).twice.and_return(true, false)
      choregraphie.cleanup.each { |block| block.call('a resource name') }
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
      choregraphie.before.each { |block| block.call('a resource name') }
    end
  end
  context 'when the condition is a block at cleanup' do

    let(:choregraphie) do
      should_fail = true
      Choregraphie::Choregraphie.new('test') do
        wait_until period: 0.001, when: 'cleanup' do
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
      choregraphie.cleanup.each { |block| block.call('a resource name') }
    end
  end
end
