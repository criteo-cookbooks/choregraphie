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
  command 'whoami'
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

execute 'whoami' do
  weight 2
end

choregraphie 'ensure_weight' do
  on :weighted_resources
  ensure_choregraphie
end

execute 'name with a, in its name' do
  command 'uname'
end

choregraphie 'execute' do
  on 'execute[converging]'
  on 'execute[not_converging]'
  on 'test_simple_resource[converging]'
  on 'test_simple_resource[not_converging]'
  on 'custom_resource[my converging custom resource]'
  on 'custom_resource[my useless custom resource]'
  on /execute\[name with a,/

  on /^log\[/

  on :weighted_resources
  on :converge_start

  before do |resource|
    filename = if resource.nil?
                 Chef::Log.warn("I am called before! for converge start")
                 'converge_start'
               else
                 Chef::Log.warn("I am called before! for resource " + resource.to_s)
                 resource.to_s.gsub(/\W+/, '_').gsub(/_$/,'')
               end
    File.open(::File.join(dir, filename), 'a') { |file| file.write("before\n") }
  end
  cleanup do |resource|
    Chef::Log.warn('I am called at cleanup for cleanup block')
    text = resource.to_s.gsub(/\W+/, '_').gsub(/_$/,'')
    File.open(::File.join(dir, 'cleanup'), 'a') { |file| file.write("#{text}\n") }
  end
  finish do
    Chef::Log.warn('I am called at finish block')
    File.open(::File.join(dir, 'cleanup'), 'a') { |file| file.write("finish") }
  end
end

log "a_log_defined_after_choregraphie"
