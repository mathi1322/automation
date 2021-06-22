class Date
  def quarter
    case self.month
    when 1,2,3
      return 1
    when 4,5,6
      return 2
    when 7,8,9
      return 3
    when 10,11,12
      return 4
    end
  end

  def previous_quarter
    (quarter == 1) ? 4 : quarter - 1
  end

  def next_quarter
    (quarter == 4) ? 1 : quarter + 1
  end

  def current_quarter_months
    quarters = [[1,2,3], [4,5,6], [7,8,9], [10,11,12]]
    quarters[quarter - 1]
  end

  def previous_quarter_months
    quarters = [[1,2,3], [4,5,6], [7,8,9], [10,11,12]]
    quarters[previous_quarter - 1]    
  end

  def self.parse_text(option_text) # eg. 'Q3 2017' or 'November 2017'
    if(option_text =~ /^Q\d/i)
      quarter_value, year_value = option_text.scan(/^Q(\d) (\d{4})/i).flatten
      quarter_start_month = [1,4,7,10].at(quarter_value.to_i - 1)
      start_date = Date.new(year_value.to_i, quarter_start_month, 1)
      end_date = Date.new(year_value.to_i, quarter_start_month + 2, -1)  
    elsif(option_text =~ /^\w+ \d{4}/)
      start_date = Date.parse(option_text, '%B %Y')
      end_date = Date.new(start_date.year, start_date.month, -1)
    else
      raise "Unknown option"
    end
    (start_date..end_date)
  end

  def self.get_range(date_obj, option) #(date_object, 'Last 7 weeks') as in LFM autoselect
    if(option =~ /^last \d/i)
      num, period = option.scan(/last (\d+) (\w+)/i).flatten
      multiplier = (period =~ /days/i) ? 1 : 30
      option_date = date_obj - (num.to_i * multiplier) + 1
    elsif(option =~ /to date$/i)
      period = option.scan(/(\w+) to date/i).flatten.first
      option_date = (period == 'Year') ? Date.parse(date_obj.strftime("%Y-01-01")) : Date.parse(date_obj.strftime("%Y-%m-01"))
    else
      raise "Unknown option"
    end
    (option_date..date_obj)
  end
end