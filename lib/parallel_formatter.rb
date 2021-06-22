require 'fileutils'
RSpec::Support.require_rspec_core "formatters"
RSpec::Support.require_rspec_core "formatters/helpers"
RSpec::Support.require_rspec_core "formatters/base_text_formatter"
RSpec::Support.require_rspec_core "formatters/html_printer"
RSpec::Support.require_rspec_core "formatters/html_formatter"

class ParallelFormatter < RSpec::Core::Formatters::HtmlFormatter
  # This registers the notifications this formatter supports, and tells
  # us that this was written against the RSpec 3.x formatter API.
  # RSpec::Core::Formatters.register self, :example_started
  RSpec::Core::Formatters.register self,:example_started, :example_passed, :example_failed,
                            :example_pending, :dump_summary, :message

  # TEST_ENV_NUMBER will be empty for the first one, then start at 2 (continues up by 1 from there)
  def initialize(output)
    # output_dir = ENV['OUTPUT_DIR']

    puts "OUTPUT DIR IS #{File.dirname(output)}"
    output_dir = File.dirname(output)
    FileUtils.mkpath(output_dir) unless File.directory?(output_dir)
    raise "Invalid output directory: #{output_dir}" unless File.directory?(output_dir)

    id = ENV['TEST_ENV_NUMBER'] || 1 # defaults to 1
    output_file = File.join(output_dir, "test-result#{id}.html")
    opened_file = File.open(output_file, 'w+')
    super(opened_file)
    @additional_screenshot = nil
    @@additional_screenshots = []
  end

  def example_passed(passed)
    description = "(TestPlan:#{passed.example.metadata[:plan]}, TestCase:#{passed.example.metadata[:case]}, Priority: #{passed.example.metadata[:priority]}', PlanPriority: #{passed.example.metadata[:run_priority]}) - #{passed.example.description}"
    @printer.move_progress(percent_done)
    @printer.print_example_passed(description, passed.example.execution_result.run_time)
    @printer.flush
    if(!@@additional_screenshots.empty?)
      @@additional_screenshots.each { |screenshot| `rm #{screenshot}` }
      @@additional_screenshots = []
    end
  end

  def example_pending(pending)
    # Do Nothing for now
    # TODO: Fix this

    # description = "(TestPlan:'#{pending.example.metadata[:plan]}', TestCase:'#{pending.example.metadata[:case]}', Priority: '#{pending.example.metadata[:priority]}', Plan Priority: '#{pending.example.metadata[:run_priority]}') - #{pending.example.description}"
    # @printer.move_progress(percent_done)
    # @printer.print_example_pending(description, "`Low priority`")
    # @printer.flush
    # if(!@@additional_screenshots.empty?)
    #   @@additional_screenshots.each { |screenshot| `rm #{screenshot}` }
    #   @@additional_screenshots = []
    # end
  end

  def message(notification)
    message = notification.message
    if(message.start_with?('screenshot:'))
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
      url = @@additional_screenshots.last.match(/\/(screenshot.+)/)[1]
      extra_screenshot_markup = "<br/>#{@additional_screenshot[0]} <br/><a href='#{url}' target='_blank'><img src='#{url}' style='width:100%'/> </a>"
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
      <td>
      <a href='#{url}' target="_blank">
      <img src='#{url}' style='width:100%'/> </a>
      #{extra_screenshot_markup}
    </td>
  </tr>
</table>
ERRDESC

    @printer.print_example_failed(
      example.execution_result.pending_fixed,
      description = "(TestPlan:#{failure.example.metadata[:plan]}, TestCase:#{failure.example.metadata[:case]}, Priority: #{failure.example.metadata[:priority]}', PlanPriority: #{failure.example.metadata[:run_priority]}) - #{failure.example.description}",
      example.execution_result.run_time,
      @failed_examples.size,
      exception_details,
      (extra == "") ? false : extra
    )
    @printer.flush
    @@additional_screenshots = []
  end

end
