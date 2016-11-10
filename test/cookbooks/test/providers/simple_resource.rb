use_inline_resources

def whyrun_supported?
  true
end

action :manage do
  require 'tmpdir'
  file ::File.join(Dir.tmpdir(), new_resource.name + '.tmp') do
    content content
  end
end
