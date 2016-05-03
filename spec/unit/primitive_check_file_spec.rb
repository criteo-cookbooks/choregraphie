require_relative '../../libraries/primitive_check_file'

describe Choregraphie::CheckFile do
  let(:choregraphie) do
    Choregraphie::Choregraphie.new('test') do
      check_file 'random', period: 0.01
    end
  end

  it 'must wait for file to be there' do
    expect(File).to receive(:exists?).and_return(false, false, false, true)
    choregraphie.before.each { |block| block.call }
  end
  it 'must clean the file in cleanup' do
    expect(File).to receive(:exists?).and_return(true)
    expect(FileUtils).to receive(:rm).with('random')
    choregraphie.cleanup.each { |block| block.call }
  end
end
