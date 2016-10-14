source 'https://rubygems.org'

gem 'berkshelf'
gem 'kitchen-vagrant'
gem 'chefspec'
gem 'rake'
gem 'foodcritic'
gem 'chef-zero-scheduled-task'
gem 'chef', '> 12.6.0'

gem 'kitchen-transport-speedy'
group :ec2 do
  gem 'test-kitchen'
  gem 'kitchen-ec2', git: 'https://github.com/criteo-forks/kitchen-ec2.git', branch: 'criteo'
  gem 'winrm',       '>= 1.6'
  gem 'winrm-fs',    '>= 0.3'
end

# Other gems should go after this comment
gem 'webmock'
gem 'diplomat'

gem 'rubocop', '=0.41.2'
gem 'winrm-elevated'
