#
# Cookbook Name:: choregraphie
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

execute 'Converging a random resource' do
  command 'uname'
end

execute 'Never converging a given resource' do
  command 'reboot'
  only_if { false }
end

choregraphie 'random service' do
  on 'execute[Converging a random resource]'
  on 'execute[Never converging a given resource]'
  before do
    Chef::Log.info("I am called before!")
  end
  after do
    Chef::Log.info("I am called after!")
  end
end
