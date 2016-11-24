require 'spec_helper'
require 'tmpdir'
dir = Dir.tmpdir()

%w(
execute_converging
test_simple_resource_converging
log_a_simple_log
log_another_log
log_a_log_defined_after_choregraphie
custom_resource_my_converging_custom_resource
execute_uname
).each do |path|
  describe file(::File.join(dir, path)) do
    it { should be_file }
  end
end

%w(
execute_not_converging
test_simple_resource_not_converging
custom_resource_my_useless_custom_resource
).each do |path|
  describe file(::File.join(dir, path)) do
    it { should_not be_file }
  end
end
