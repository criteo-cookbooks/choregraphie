#
# Cookbook Name:: choregraphie
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

require 'tmpdir'
dir = Dir.tmpdir()

directory dir

# Need to clean up in case of multiple convergence tests
execute 'Clean up machine' do
  command "rm #{::File.join(dir, 'not_converging.tmp')}"
  only_if "test -f #{::File.join(dir, 'not_converging.tmp')}"
end

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
file ::File.join(dir, 'not_converging.tmp') do
  content 'not_converging'
end

test_simple_resource 'not_converging' do
  content 'not_converging'
  only_if { false }
end

log "a_simple_log"
log "another_log"

custom_resource 'my converging custom resource'

custom_resource 'my useless custom resource' do
  only_if { false }
end

execute 'uname' do
  weight 2
end

choregraphie 'execute' do
  on 'execute[converging]'
  on 'execute[not_converging]'
  on 'test_simple_resource[converging]'
  on 'test_simple_resource[not_converging]'
  on 'custom_resource[my converging custom resource]'
  on 'custom_resource[my useless custom resource]'

  on /^log\[/

  on :weighted_resources

  before do |resource|
    Chef::Log.warn("I am called before! for resource " + resource.to_s)
    filename = resource.to_s.gsub(/\W+/, '_').gsub(/_$/,'')
    require 'fileutils'
    require 'tmpdir'
    dir = Dir.tmpdir()
    FileUtils.touch(::File.join(dir, filename))
  end
  cleanup do
    Chef::Log.warn('I am called at the end')
  end
end

log "a_log_defined_after_choregraphie"
