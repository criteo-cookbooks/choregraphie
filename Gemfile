source 'https://rubygems.org'

gem 'berkshelf'
gem 'kitchen-vagrant'
gem 'chefspec'
gem 'rake'
gem 'foodcritic'
gem 'chef-zero-scheduled-task'
gem 'chef'

gem 'kitchen-transport-speedy'
group :ec2 do
  gem 'test-kitchen'
  gem 'kitchen-ec2', git: 'https://github.com/criteo-forks/kitchen-ec2.git', branch: 'criteo'
  gem 'winrm',       '>= 1.6'
  gem 'winrm-fs',    '>= 0.3'
  gem 'dotenv'
end

# Other gems should go after this comment
gem 'webmock'
gem 'diplomat',      '>= 2.0.2'

gem 'winrm-elevated'
gem 'rubocop', '=0.45.0'
