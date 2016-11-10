# This custom resource explicitely supports whyrun using work-around described
# on https://github.com/chef/chef/issues/4537

resource_name :custom_resource

provides :custom_resource

action :create do
  require 'tmpdir'
  file ::File.join(Dir.tmpdir(), 'hi')
end

action_class do
  def whyrun_supported?
    true
  end
end
