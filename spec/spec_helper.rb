require 'chefspec'
require 'chefspec/berkshelf'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow: [
  %r{127.0.0.1:\d+/(sandboxes|file_store|cookbooks|nodes|environments)},
  %r{supermarket.chef.io},
])
