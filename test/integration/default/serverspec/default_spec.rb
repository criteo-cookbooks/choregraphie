require 'spec_helper'
describe file('/tmp/execute_converging') do
  it { should be_file }
end
describe file('/tmp/execute_not_converging') do
  it { should_not be_file }
end

describe file('/tmp/test_simple_resource_converging') do
  it { should be_file }
end
describe file('/tmp/test_simple_resource_not_converging') do
  it { should_not be_file }
end

describe file('/tmp/log_a_simple_log') do
  it { should be_file }
end
describe file('/tmp/log_another_log') do
  it { should be_file }
end
describe file('/tmp/log_a_log_defined_after_choregraphie') do
  it { should be_file }
end
