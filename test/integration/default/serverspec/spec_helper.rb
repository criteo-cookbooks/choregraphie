require 'serverspec'

if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
  set :backend, :cmd
  set :os, family: 'windows'
end
