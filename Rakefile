require 'rspec/core/rake_task'
require 'kitchen'
require 'foodcritic'

FoodCritic::Rake::LintTask.new
RSpec::Core::RakeTask.new(:rspec)


desc 'Run kitchen tests'
task :test_kitchen do
  Kitchen.logger = Kitchen.default_file_logger
  @loader = Kitchen::Loader::YAML.new(project_config: './.kitchen.ec2.yml')
  config = Kitchen::Config.new(loader: @loader)
  if ENV['KITCHEN_NO_CONCURRENCY']
    config.instances.each do |instance|
      instance.test(:always)
    end
  else
    threads = []
    config.instances.each do |instance|
      threads << Thread.new { instance.test(:always) }
    end
    threads.map(&:join)
  end
end

tasks = [:foodcritic, :rspec]
tasks << :test_kitchen if ENV['encrypted_144c35c6f3c3_iv']
task default: tasks
