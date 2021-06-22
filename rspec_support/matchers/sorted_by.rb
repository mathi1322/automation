RSpec::Matchers.define :be_sorted_by do |field, direction|
  match do |actual|
    actual.sorted_by?(direction) { |item|
      if item.is_a? Hash
        item[field]
      else
        item.public_send(field)
      end
    }
  end
end

RSpec::Matchers.define :be_sorted_in do |direction|
  match do |actual|
    actual.sorted_by?(direction) {|item| item }
  end
end
