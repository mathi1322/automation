module Enumerable
  SPECIAL_ORDER = [false, true].freeze

  def sorted?(direction = :asc)
    if direction == :asc
      each_cons(2).all? { |a, b| (compare(a, b) <= 0) }
    else
      each_cons(2).all? { |a, b| (compare(a, b) >= 0) }
    end
  end

  def sorted_by?(direction = :asc, &block)
    lazy.map(&block).sorted?(direction)
  end

  def values(field_name)
    collect { |col| col[field_name] }.sort
  end

  def compare(a, b)
    if a && b
      if [a, b].all? { |v| SPECIAL_ORDER.include?(v) }
        SPECIAL_ORDER.index(a) <=> SPECIAL_ORDER.index(b)
      elsif [a, b].any? { |v| SPECIAL_ORDER.include?(v) }
        SPECIAL_ORDER.include?(a) ? -1 : 1
      else
        a <=> b
      end
    elsif is_boolean?(a) && is_boolean?(b)
      SPECIAL_ORDER.index(a) <=> SPECIAL_ORDER.index(b)
    else
      a ? -1 : 1
    end
  end

  def is_boolean?(value)
    !!value == value
  end

  def to_average
    (total.to_f / integers.count) if self.class == Array
  end

  def mode
    freq = each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }
    max = freq.values.max
    freq.select { |_k, f| f == max }.collect(&:first)
  end
end
