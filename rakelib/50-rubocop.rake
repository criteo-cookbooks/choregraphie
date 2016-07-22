namespace :rubocop do
  require 'mixlib/shellout'

  def rubocop_version
    last_version = Mixlib::ShellOut.new('gem list "^rubocop$" --remote')
    last_version.run_command.error!
    last_version.stdout.gsub(/rubocop \((.*)\)/, '\1').chomp
  end

  desc 'Show latest rubocop gem version'
  task :latest_version do
    puts rubocop_version
  end

  desc 'Constrain rubocop version to latest and update'
  task :force_latest_version do
    v = rubocop_version
    gemfile = ::File.join(::File.dirname(__FILE__), '..' , 'Gemfile')
    content = ::File.read(gemfile).lines.reject { |line| line =~ /gem 'rubocop'/ }.join
    File.open(gemfile, 'w+') do |f|
      f.write(content)
      f.write("gem 'rubocop', '=#{v}'\n")
    end
    puts "Forced rubocop to #{v} in Gemfile"
    Bundler.with_clean_env do
      Mixlib::ShellOut.new('bundle update rubocop').run_command.error!
    end
    puts "Updated rubocop to #{v}"
  end
end
