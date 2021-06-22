class String
  def rgbatohex
    value = self
    rgb_as_hex = ""
    rgb_arr = value.match(/\((.*)\)/)[1].split(", ")
    rgb_arr.pop
    rgb_arr.each { |component| rgb_as_hex << component.to_i.to_s(16).rjust(2, "0") }
    "##{rgb_as_hex}"
  end

  def color_to_hex
    value = self
    return value.upcase if value.match(/^#[0-9A-F]+$/i)
    rgb_as_hex = ""
    rgb_arr = value.match(/\((.*)\)/)[1].split(", ")
    rgb_arr.pop if value.match(/rgba/)
    rgb_arr.each { |component| rgb_as_hex << component.to_i.to_s(16).rjust(2, "0") }
    "##{rgb_as_hex}".upcase
  end

  def blank?
    self.strip.empty?
  end

  def number?
    !self.match(/^\d+$/).nil?
  end

  def float?
    self =~ /\d+\.\d+/
  end

  def titleize
    split(" ")
      .map { |word| word[0].upcase + word[1..-1].downcase }
      .join(" ")
  end

  def symbolic_key
    self.downcase
        .strip
        .gsub(/[\s-]+/, "_")
        .tr("()+", "")
        .to_sym
  end

  def zero?
    self == "0"
  end

  def hms_to_seconds # hms -> eg. 2h30m45s to 9045
    return if (self.empty?)
    value = self
    total_sec = 0
    if !value.match(/\d.*h/).nil?
      total_sec = total_sec + value.match(/(\d+)h/)[1].to_i * 60 * 60
    end
    if !value.match(/\d.*m/).nil?
      total_sec = total_sec + value.match(/(\d+)m/)[1].to_i * 60
    end
    if !value.match(/\d.*s/).nil?
      if (value.match(/0\.\d+s/))
        total_sec = value.match(/(0\.\d+)s/)[1].to_f
      else
        total_sec = total_sec + value.match(/(\d+)s/)[1].to_i
      end
    end
    total_sec
  end

  def to_duration_format(opts = { milliseconds_precision: 3 }) # HH:mm:ss.SSSS format to 2h30m45.452s
    hours, minutes, seconds, milliseconds = self.scan(/(\d+):(\d+):(\d+)\.?(\d+)?/).flatten.map(&:to_i)
    unless hours.nil?
      h = hours > 0 ? "#{hours}h" : ""
      m = minutes > 0 ? "#{minutes}m" : ""
    end
    seconds_with_ms = milliseconds.zero? ? seconds : seconds + (milliseconds * 0.001)
    if (milliseconds > 0)
      s_unrounded = "#{seconds_with_ms.round(opts[:milliseconds_precision])}"
      s_unrounded = s_unrounded.round_float_value if s_unrounded.match?(/\d+\.5$/)
      if seconds == 0 && milliseconds < 5
        s = "<0.01s" # for minor duration
      else
        s = "#{s_unrounded}s"
      end
    else
      s = "#{seconds_with_ms.to_i}s"
    end
    "#{h}#{m}#{s}"
  end

  private

  def float_mod(value)
    if value % 1 == 0
      return value.to_i
    else
      value
    end
  end
end
