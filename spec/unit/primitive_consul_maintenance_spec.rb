require_relative '../../libraries/primitive_consul_maintenance'
require 'diplomat'

describe Choregraphie::ConsulMaintenance do
  let(:choregraphie) do
    Choregraphie::Choregraphie.new('test') do
      consul_maintenance reason: 'Testing'
    end
  end

  context 'When using consul_maintenance' do
    it 'Must enable maintenance mode before' do
      expect(Diplomat::Maintenance).to receive(:enable).with(true, 'Testing').and_return(true)
      choregraphie.before.each { |block| block.call }
    end

    it 'Must disable maintenance mode before' do
      expect(Diplomat::Maintenance).to receive(:enable).with(false, 'Testing').and_return(true)
      choregraphie.cleanup.each { |block| block.call }
    end
  end
end
