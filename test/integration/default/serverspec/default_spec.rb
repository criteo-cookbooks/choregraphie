require 'spec_helper'

%w(
/tmp/execute_converging
/tmp/test_simple_resource_converging
/tmp/log_a_simple_log
/tmp/log_another_log
/tmp/log_a_log_defined_after_choregraphie
/tmp/custom_resource_my_converging_custom_resource
).each do |path|
  describe file(path) do
    it { should be_file }
  end
end

%w(
/tmp/execute_not_converging
/tmp/test_simple_resource_not_converging
/tmp/custom_resource_my_useless_custom_resource
).each do |path|
  describe file(path) do
    it { should_not be_file }
  end
end
