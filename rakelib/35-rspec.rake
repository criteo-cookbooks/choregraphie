require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:rspec) do |t|
  t.rspec_opts = '-fd'
end

task default: [:rspec]
