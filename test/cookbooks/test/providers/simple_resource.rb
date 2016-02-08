use_inline_resources

def whyrun_supported?
  true
end

action :manage do
  file ::File.join('/tmp/', new_resource.name + '.tmp') do
    content content
  end
end
