RSpec::Matchers.define :be_clickable do
  match do |actual|
    !(actual['class'].include?('disabled') || actual.disabled?)
  end
end
