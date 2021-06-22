require_relative './clickable.rb'

RSpec::Matchers.define :be_enabled do
  match do |actual|
    expect(actual).to be_clickable
  end
end
