require 'spec_helper'

describe 'test::default' do
  context 'When all attributes are default, on centos 7.5.1804' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(
        platform: 'centos',
        version: '7.8.2003',
      ) { ::Choregraphie::Choregraphie.clear }
      stub_command("test -f #{Dir.tmpdir}/not_converging.tmp").and_return(0)
      runner.converge(described_recipe)
    end

    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
  end
  context 'When all attributes are default, on windows 8.1' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(
        platform: 'windows',
        version: '8.1',
      ) { ::Choregraphie::Choregraphie.clear }
      stub_command("test -f #{Dir.tmpdir}/not_converging.tmp").and_return(0)
      runner.converge(described_recipe)
    end

    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
  end
end
