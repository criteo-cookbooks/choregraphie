require 'tmpdir'
dir = Dir.tmpdir

%w[
  execute_converging
  test_simple_resource_converging
  execute_uname
  execute_uname_a
  execute_echo_a_command_defined_after_choregraphie
  custom_resource_my_converging_custom_resource
  execute_whoami
].each do |path|
  describe file(::File.join(dir, path)) do
    it { should be_file }
  end
  describe file(::File.join(dir, 'cleanup')) do
    its(:content) { should match(/\nfinish$/) }
  end
end

%w[
  execute_not_converging
  test_simple_resource_not_converging
  custom_resource_my_useless_custom_resource
].each do |path|
  describe file(::File.join(dir, path)) do
    it { should_not be_file }
  end
end
