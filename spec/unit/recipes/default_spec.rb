#
# Cookbook Name:: choregraphie
# Spec:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

require 'spec_helper'

describe 'test::default' do
  context 'When all attributes are default, on centos 6.7' do
    let(:chef_run) do
      runner = ChefSpec::ServerRunner.new(
        platform: 'centos',
        version:  '6.7'
      )
      stub_command("test -f /tmp/not_converging.tmp").and_return(0)
      runner.converge(described_recipe)
    end

    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
  end
  context 'When all attributes are default, on centos 7.2.1511' do
    let(:chef_run) do
      runner = ChefSpec::ServerRunner.new(
        platform: 'centos',
        version:  '7.2.1511'
      )
      stub_command("test -f /tmp/not_converging.tmp").and_return(0)
      runner.converge(described_recipe)
    end

    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
  end
  context 'When all attributes are default, on windows 6.3.9600' do
    let(:chef_run) do
      runner = ChefSpec::ServerRunner.new(
        platform: 'windows',
        version:  '2008R2'
      )
      stub_command("test -f /tmp/not_converging.tmp").and_return(0)
      runner.converge(described_recipe)
    end

    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
  end
end
