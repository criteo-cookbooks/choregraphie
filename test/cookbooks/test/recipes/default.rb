#
# Cookbook Name:: choregraphie
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.


# Using chef provided resource
execute 'converging' do
  command 'uname'
end
execute 'not_converging' do
  command 'reboot'
  only_if { false }
end

# Simple resource/provider kind resource.
# This is the most common kind of resource define internally
test_simple_resource 'converging' do
  content 'test!'
end
file '/tmp/not_converging.tmp' do
  content 'not_converging'
end

test_simple_resource 'not_converging' do
  content 'not_converging'
  only_if { false }
end


choregraphie 'execute' do
  on 'execute[converging]'
  on 'execute[not_converging]'
  on 'test_simple_resource[converging]'
  on 'test_simple_resource[not_converging]'
  before do |resource|
    Chef::Log.info("I am called before! for resource " + resource.to_s)
    filename = resource.to_s.gsub(/\W+/, '_').gsub(/_$/,'')
    require 'fileutils'
    FileUtils.touch(::File.join('/tmp', filename))
  end
  cleanup do
    Chef::Log.info("I am called at the end!")
  end
end
