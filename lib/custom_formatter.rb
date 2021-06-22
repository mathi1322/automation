class CustomFormatter < RSpec::Core::Formatters::HtmlFormatter
  # This registers the notifications this formatter supports, and tells
  # us that this was written against the RSpec 3.x formatter API.
  # RSpec::Core::Formatters.register self, :example_started
  RSpec::Core::Formatters.register self,:example_started, :example_passed, :example_failed,
                            :example_pending, :dump_summary, :message

  def initialize(output)
    puts "OUTPUT DIR IS #{File.dirname(output)}"
    output_dir = File.dirname(output)
    FileUtils.mkpath(output_dir) unless File.directory?(output_dir)
    raise "Invalid output directory: #{output_dir}" unless File.directory?(output_dir)
    # output_file = File.join(output_dir, "index.html")
    opened_file = File.open(output, 'w+')
    super(opened_file)
    @additional_screenshot = nil
    @@additional_screenshots = []
  end

  def example_passed(passed)
    description = "(TestPlan:'#{passed.example.metadata[:plan]}', TestCase:'#{passed.example.metadata[:case]}') - #{passed.example.description}"
    @printer.move_progress(percent_done)
    @printer.print_example_passed(description, passed.example.execution_result.run_time)
    @printer.flush
    if(!@@additional_screenshots.empty?)
      @@additional_screenshots.each { |screenshot| `rm #{screenshot}` }
      @@additional_screenshots = []
    end
  end

  def message(notification)
    message = notification.message
    if(message.is_a?(String) && message.start_with?('screenshot:'))
      fragments = message.split(':')
      @additional_screenshot = fragments[1..2]
      @@additional_screenshots << @additional_screenshot[1]
    end
  end

  def example_failed(failure)
    @failed_examples << failure.example
    unless @header_red
      @header_red = true
      @printer.make_header_red
    end

    unless @example_group_red
      @example_group_red = true
      @printer.make_example_group_header_red(example_group_number)
    end

    extra_screenshot_markup = ""
    unless(@@additional_screenshots.empty?)
      extra_screenshot_markup = "<br/>#{@additional_screenshot[0]}<br/><img src='#{@@additional_screenshots.last}' style='width:100%'/> </a>"
      @@additional_screenshots[0..-2].each { |screenshot| `rm #{screenshot}` } if @@additional_screenshots.length > 1
    end

    @printer.move_progress(percent_done)

    example = failure.example

    exception = failure.exception
    exception_details = if exception
                          {
                            :message => exception.message,
                            :backtrace => failure.formatted_backtrace.join("\n")
                          }
                        end
    snippet = extra_failure_content(failure)
    url = "screenshot-#{example.metadata[:plan]}-#{example.metadata[:case]}-#{example.description.gsub(/\s/, "_")}.png"
    jira_url = "https://listenfirstmedia.atlassian.net/browse/QA-#{example.metadata[:case]}"

    extra = <<-ERRDESC
<table width="100%" border="1px">
  <tr>
    <td width="50%">
      <div style="font-size:medium;color:black">
        JIRA URL <a href=#{jira_url} style='color:blue'> #{jira_url} </a>
      </div>
      <br/>
      #{snippet}
    </td>
      <td><a href='#{url}' target="_blank">
      <img src='#{url}' style='width:100%'/> </a>
      #{extra_screenshot_markup}
    </td>
  </tr>
</table>
ERRDESC

    @printer.print_example_failed(
      example.execution_result.pending_fixed,
      description = "(Test Plan:'#{example.metadata[:plan]}', Test Case:'#{example.metadata[:case]}') - #{example.description}",
      example.execution_result.run_time,
      @failed_examples.size,
      exception_details,
      (extra == "") ? false : extra
    )
    @printer.flush
    @@additional_screenshots = []
  end

end
