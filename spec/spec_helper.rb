require 'chefspec'
require 'chefspec/berkshelf'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow: [
  %r{127.0.0.1:\d+/(sandboxes|file_store|cookbooks|nodes|environments)},
  %r{supermarket.chef.io},
  %r{s3.amazonaws.com},
])

RSpec.configure do |config|
  config.before :each do
    # Reset chef between all tests. Otherwise choregraphie blocks from various
    # specs are concatenated
    Chef::Config.reset
  end end

