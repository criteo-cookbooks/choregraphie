namespace :rubocop do
  require 'mixlib/shellout'

  def rubocop_version
    last_version = Mixlib::ShellOut.new('gem list "^rubocop$" --remote')
    last_version.run_command.error!
    # When gem 'verbose' mode active the output is:
    # $ gem list "^rubocop$" --remote
    #
    # *** REMOTE GEMS ***
    #
    # GET https://api.rubygems.org/latest_specs.4.8.gz
    # 302 Moved Temporarily
    # GET https://rubygems.global.ssl.fastly.net/latest_specs.4.8.gz
    # 304 Not Modified
    # rubocop (0.42.0)
    #
    last_version.stdout[/^rubocop \(.*\)/].gsub(/.*\((.*)\)/, '\1').chomp
  end

  desc 'Show latest rubocop gem version'
  task :latest_version do
    puts rubocop_version
  end

  desc 'Constrain rubocop version to latest and update'
  task :force_latest_version do
    v = rubocop_version
    gemfile = ::File.join(::File.dirname(__FILE__), '..', 'Gemfile')
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
