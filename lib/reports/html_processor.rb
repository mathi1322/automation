RSpec::Support.require_rspec_core "formatters/html_printer"

module Reports
  class HtmlProcessor
    def initialize(output)
      @example_group = nil
      @failed_examples = []
      @example_group_number = 0
      @example_number = 0
      @header_red = nil
      @output = output
      @printer = RSpec::Core::Formatters::HtmlPrinter.new(File.new(output, 'w+'))
    end

    attr_reader :output

    def self.process(json, output)
      printer = self.new(output)
      printer.start(json[:summary][:example_count])
      depth = 1
      process_html(printer, json[:specs], depth)
      printer.start_dump
      printer.dump_summary(json[:summary])
      printer.close
    end

    def start(example_count)
      start_sync_output
      @example_count = example_count
      @printer.print_html_start
      @printer.flush
    end

    def example_group_started(group)
      @example_group = group
      @example_group_red = false
      @example_group_number += 1

      @printer.print_example_group_end unless example_group_number == 1
      @printer.print_example_group_start(example_group_number,
                                         group[:description],
                                         group[:parent_count])
      @printer.flush
    end

    def start_dump
      @printer.print_example_group_end
      @printer.flush
    end

    def example_started(example)
      @example_number += 1
    end

    def example_passed(example)
      @printer.move_progress(percent_done)
      @printer.print_example_passed(description(example), example[:run_time])
      @printer.flush
    end

    def example_failed(example)
      @failed_examples << example
      unless @header_red
        @header_red = true
        @printer.make_header_red
      end

      unless @example_group_red
        @example_group_red = true
        @printer.make_example_group_header_red(example_group_number)
      end

      @printer.move_progress(percent_done)


      exception = example[:failure]
      exception_details = if exception
                            {
                              :message => exception[:message],
                              :backtrace => exception[:backtrace]
                            }
                          end
      extra = extra_failure_content(example)

      @printer.print_example_failed(
        false,
        description(example),
        example[:run_time],
        @failed_examples.size,
        exception_details,
        (extra == "") ? false : extra
      )
      @printer.flush
    end

    def example_pending(example)
      @printer.make_header_yellow unless @header_red
      @printer.make_example_group_header_yellow(example_group_number) unless @example_group_red
      @printer.move_progress(percent_done)
      @printer.print_example_pending(description(example), example[:pending_message])
      @printer.flush
    end

    def dump_summary(summary)
      @printer.print_summary(
        summary[:duration],
        summary[:example_count],
        summary[:failure_count],
        summary[:pending_count]
      )
      @printer.flush
    end

    # @api public
    #
    # @param _notification [NullNotification] (Ignored)
    # @see RSpec::Core::Formatters::Protocol#close
    def close
      restore_sync_output
    end

    private

    def description(example)
      "#{example.slice(:plan, :case, :priority, :run_priority)} - #{example[:description]}"
    end
    def self.process_html(printer, items, depth)
      items.each { |item|
        if(item[:type] == 'group')
          item[:parent_count] = depth unless(item.key?(:parent_count))
          printer.example_group_started(item)
          process_html(printer, item[:children], depth + 1)
        elsif(item[:type] == 'example')
          printer.example_started(item)
          if(item[:status] == 'passed')
            printer.example_passed(item)
          elsif(item[:status] == 'failed')
            printer.example_failed(item)
          elsif(item[:status] == 'pending')
            printer.example_pending(item)
          else
            raise "Unknown status #{item}"
          end
        end
      }
    end

    def start_sync_output
      @old_sync, output.sync = output.sync, true if output_supports_sync
    end

    def restore_sync_output
      output.sync = @old_sync if output_supports_sync && !output.closed?
    end

    def output_supports_sync
      output.respond_to?(:sync=)
    end

    # If these methods are declared with attr_reader Ruby will issue a
    # warning because they are private.
    # rubocop:disable Style/TrivialAccessors

    # The number of the currently running example_group.
    def example_group_number
      @example_group_number
    end

    # The number of the currently running example (a global counter).
    def example_number
      @example_number
    end
    # rubocop:enable Style/TrivialAccessors

    def percent_done
      result = 100.0
      if @example_count > 0
        result = (((example_number).to_f / @example_count.to_f * 1000).to_i / 10.0).to_f
      end
      result
    end

    def extra_failure_content(meta)
      snippet = begin
        RSpec::Support.require_rspec_core "formatters/html_snippet_extractor"
        backtrace = (meta[:failure].[](:backtrace)&.split("\n") || []).map do |line|
          RSpec.configuration.backtrace_formatter.backtrace_line(line)
        end
        backtrace.compact!
        @snippet_extractor ||= RSpec::Core::Formatters::HtmlSnippetExtractor.new
        "    <pre class=\"ruby\"><code>#{@snippet_extractor.snippet(backtrace)}</code></pre>"
      end
      url = "screenshot-#{meta[:plan]}-#{meta[:case]}-#{meta[:description].gsub(/\s/, "_")}.png"
      jira_url = "https://listenfirstmedia.atlassian.net/browse/QA-#{meta[:case]}"
      extra_screenshot_markup = nil
      screenshot = meta[:failure].[](:screenshot)
      if(screenshot)
        extra_screenshot_markup = "<br/>#{screenshot}<br/><a href='#{screenshot}'><img src='#{screenshot}' style='width:100%'/> </a>"
      end
      extra = <<~HTML
        <table width="100%" border="1px">
          <tr>
            <td colspan="2">
              #{meta.slice(:plan, :case, :priority, :run_priority)}
            </td>
          </tr>
          <tr>
            <td width="50%">
              <div style="font-size:medium;color:black">
                JIRA URL <a href=#{jira_url} style='color:blue'> #{jira_url} </a>
              </div>
              <br/>
              #{snippet}
            </td>
              <td>
                #{extra_screenshot_markup}
              </td>
          </tr>
        </table>
      HTML
    end
  end
end