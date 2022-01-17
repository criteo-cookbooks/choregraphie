require 'chefspec'
require 'chefspec/berkshelf'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow: [
                               %r{127.0.0.1:\d+/(sandboxes|file_store|cookbooks|nodes|environments)},
                               /supermarket.chef.io/,
                               /s3.amazonaws.com/,
                               /fauxhai/
                             ])

RSpec.configure do |config|
  config.before :each do
    # Reset Chef between all tests. Otherwise choregraphie blocks from various
    # specs are concatenated
    Chef::Config.reset
  end
end

if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
  set :backend, :cmd
  set :os, family: 'windows'
end
