require 'ostruct'
class Object
  def to_ostruct
    case self
    when Hash
      OpenStruct.new(Hash[self.map {|k, v| [k, v.to_ostruct] }])
    when Array
      self.map {|x| x.to_ostruct }
    else
      self
    end
  end
end
