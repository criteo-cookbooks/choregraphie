source 'https://rubygems.org'

gem 'berkshelf'
gem 'chef'
gem 'chefspec', '< 7.3.0'
gem 'chef-zero-scheduled-task'
gem 'foodcritic'
gem 'kitchen-dokken'
gem 'kitchen-vagrant'
gem 'rake'
gem 'serverspec'

gem 'kitchen-transport-speedy'
group :ec2 do
  gem 'dotenv'
  gem 'kitchen-ec2', git: 'https://github.com/criteo-forks/kitchen-ec2.git', branch: 'criteo'
  gem 'test-kitchen'
  gem 'winrm', '>= 1.6'
  gem 'winrm-fs', '>= 0.3'
end

# Other gems should go after this comment
gem 'diplomat', '>= 2.0.2'
gem 'webmock'

gem 'openssl', '>= 2.1.2'
gem 'pry'
gem 'rubocop'
gem 'winrm-elevated'
