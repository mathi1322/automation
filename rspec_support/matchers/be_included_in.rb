RSpec::Matchers.define :be_included_in do |expected|
  match do |actual|
    expected.include?(actual)
  end
end
