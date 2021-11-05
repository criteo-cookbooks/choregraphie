require_relative '../../libraries/primitive_ensure_choregraphie'

describe Choregraphie::EnsureChoregraphie do
  let(:choregraphie) do
    Choregraphie::Choregraphie.new('test') do
      on 'test[name]'
      ensure_choregraphie 'random', period: 0.01
    end
  end
  before(:each) do
    expect_any_instance_of(Choregraphie::Choregraphie).to receive(:ruby_block)
  end

  it 'must check file if resource is not protected' do
    expect(Choregraphie::Choregraphie).to receive(:all).and_return(
      [
        double(name: 'toto', resources: ['toto[name]'])
      ],
    )
    expect(File).to receive(:exist?).with('random').and_return(true)
    choregraphie.before.each { |block| block.call 'test[name]' }
  end
  it 'must not check file if resource is protected' do
    expect(Choregraphie::Choregraphie).to receive(:all).and_return(
      [
        double(name: 'test', resources: ['test[name]']),
        double(name: 'toto', resources: ['toto[name]'])
      ],
    )
    expect(File).to_not receive(:exist?).with('random')
    choregraphie.before.each { |block| block.call 'test[name]' }
  end
  it 'must clean the file in cleanup' do
    expect(File).to receive(:exist?).and_return(true)
    expect(FileUtils).to receive(:rm).with('random')
    choregraphie.cleanup.each { |block| block.call }
  end
end
