module Reports
  class G
    def initialize(data)
      @groups = []
      @examples = []
      @data = data.tap { |d| 
        data[:type] = :group
        data[:failed] = false
      }
    end

    def failed!() @data[:failed] = true; end

    def to_json(options = {})
      @data
        .merge({children: groups.concat(examples)})
        .to_json(options)
    end

    attr_reader :groups, :examples
  end

  class E
    def initialize(data)
      @data = data.tap { |d| d[:type] = :example }
    end
    attr_reader :data
    def to_json(options = {})
      @data.to_json(options)
    end

    def failed!(details)
      data[:failure] = details
    end
  end

  def meta_e(example)
    {
      :description => example.description,
      :full_description => example.full_description,
      :status => example.execution_result.status.to_s,
      :file_path => example.metadata[:file_path],
      :line_number  => example.metadata[:line_number],
      :run_time => example.execution_result.run_time,
      :pending_message => example.execution_result.pending_message,
      :plan => example.metadata[:plan],
      :case => example.metadata[:case],
      :priority => example.metadata[:priority],
      :run_priority => example.metadata[:run_priority]
    }
  end

  def meta_g(group)
    {
      description: group.description,
      file_path: group.file_path,
      parent_count: group.parent_groups.size
    }
  end

  def g(group)
    Reports::G.new(meta_g(group))
  end

  def e(example)
    Reports::E.new(meta_e(example))
  end

  def failure(notification, screenshot = nil)
    if notification.exception
      {
        message: notification.message_lines.join("\n"),
        backtrace: notification.formatted_backtrace.join("\n"),
      }.tap {|m| m[:screenshot] = screenshot if screenshot }
    end
  end

  def summary(notification)
    {
      duration: notification.duration,
      example_count: notification.example_count,
      failure_count: notification.failure_count,
      pending_count: notification.pending_count
    }
  end

  def output
    @output ||= begin
      dir = ENV['REPORTS_DIRECTORY'] || "#{$ROOT}/reports"
      filename = ENV['REPORTS_FILE'] || 'index'
      FileUtils.mkdir_p(dir)
      "#{dir}/#{filename}#{ENV['TEST_ENV_NUMBER']}"
    end
  end
end