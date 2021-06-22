module RSpec
  module Core
    class Example
      attr_accessor :attempts

      def clear_exception
        @exception = nil
      end

      class Procsy
        def run_with_retry(opts = {})
          RSpec::Retry.new(self, opts).run
        end
      end
    end
  end
end

class CapybaraRetry
  # borrowed from ActiveSupport::Inflector
  @@current_session = Capybara.session_name
  def self.ordinalize(number)
    if (11..13).cover?(number.to_i % 100)
      "#{number}th"
    else
      case number.to_i % 10
      when 1 then "#{number}st"
      when 2 then "#{number}nd"
      when 3 then "#{number}rd"
      else "#{number}th"
      end
    end
  end

  def self.attempts
    RSpec.current_example.attempts || 0
  end

  def self.attempts=(v)
    RSpec.current_example.attempts = v
  end

  def self.verbose_retry?
    RSpec.configuration.verbose_retry?
  end

  def self.reload
    Capybara.page.evaluate_script("window.location.reload()")
  end

  def self.display_try_failure_messages?
    RSpec.configuration.display_try_failure_messages?
  end

  def self.run_with_retry(ex, retry_count = 3)
    example = RSpec.current_example
    Capybara.session_name = @@current_session unless Capybara.session_name == @@current_session
    self.attempts = 0
    start_time = Time.now
    $LOG.info "case:#{example.metadata[:case]}, running: #{example.location}"
    loop do
      if attempts > 0
        RSpec.configuration.formatters.each { |f| f.retry(example) if f.respond_to? :retry }
        if verbose_retry?
          message = "RSpec::Retry: #{ordinalize(attempts + 1)} try #{example.location}"
          message = "\n" + message if attempts == 1
          RSpec.configuration.reporter.message(message)
        end
      end

      example.clear_exception
      session_name = ENV["CURRENT_SESSION"] || @@current_session
      Capybara.session_name = session_name.to_sym
      ex.run
      self.attempts += 1

      exception = example.exception
      unless exception.nil?
        error_msg = exception.to_s.gsub(/\t|\n|/, "")
        TestBench.log_event("ErrorEvent", exception: error_msg)
      end

      if exception.is_a?(Selenium::WebDriver::Error::UnknownError) && exception.message.match(/not clickable/)
        # TODO: Instead of resizing on error, we should find which causes the browser to shrink its size
        # Capybara.page.driver.browser.manage.window.resize_to(1600, 1200)
        sleep 2
      end

      if exception.nil? || (self.attempts >= retry_count)
        duration = (Time.now - start_time) % 60
        data = {
          retries: self.attempts,
          duration: duration,
          test_plan_id: example.metadata[:plan],
          test_case_id: example.metadata[:case],
          example_description: example.description,
        }
        message = "attempts:#{self.attempts},duration:#{duration},plan:#{example.metadata[:plan]},case:#{example.metadata[:case]} - #{example.description.gsub(/\s/, "_")}"
        method = :info
        unless exception.nil?
          data[:error_description] = exception.message.to_s
          data[:error_description] = data[:error_description][0, 950] if data[:error_description].length > 950
          message = "error:#{exception.class.name},#{message}"
          method = :error
        end
        $LOG.public_send(method, message)
        break if exception.nil?
      end

      if exception.is_a?(Selenium::WebDriver::Error::UnknownError) && exception.message.match(/not clickable/)
        # TODO: Instead of resizing on error, we should find which causes the browser to shrink its size
        # Capybara.page.driver.browser.manage.window.resize_to(1600, 1200)
        sleep 2
      elsif exception.is_a?(RSpec::Core::MultipleExceptionError)
        # When alert was not handled it would cause subsequent tests to fail
        # To avoid that, alert needs to be dismissed
        # RSpec::Core::MultipleExceptionError is the error we get when unhandled alert is open
        Capybara.page.driver.browser.switch_to.alert.dismiss
      elsif exception.is_a?(Capybara::ElementNotFound) || exception.is_a?(Automation::InvalidPage) || exception.is_a?(Selenium::WebDriver::Error::UnknownError) || exception.is_a?(Selenium::WebDriver::Error::UnhandledAlertError) || exception.is_a?(SitePrism::TimeoutError)
        if Capybara.page.windows.count > 1
          Capybara.page.windows.reverse.each do |window|
            Capybara.page.switch_to_window(window)
            reload
            sleep 2
            reload
            SitePrism::Waiter.wait_until_true(20) do
              Capybara.page.has_no_css?("i.fa-spinner")
            end
          end
          Capybara.page.switch_to_window(Capybara.page.windows.first) # to ensure browser on first tab
        end
        reload
      elsif exception.is_a?(Net::ReadTimeout) || exception.is_a?(Selenium::WebDriver::Error::NoSuchDriverError)
        $LOG.warn("Abandoning unresponsive session. message: exception.message, exception: exception.class.name, case:example.metadata[:case], description: #{example.description}")
        @@current_session = (@@current_session.to_s + "_1").to_sym
        Capybara.page.windows.each(&:close) # to save cpu memory
        TestBench.log_event("BrowserAbandon")
        Capybara.session_name = @@current_session
        ENV["CURRENT_SESSION"] = @@current_session
        RSpec.configuration.reporter.message("Changing capybara_session to #{Capybara.session_name}")
      elsif !exception.nil?
        reload
      end

      if verbose_retry? && display_try_failure_messages?
        if attempts != retry_count
          exception_strings = begin
              if ::RSpec::Core::MultipleExceptionError::InterfaceTag === exception
                exception.all_exceptions.map(&:to_s)
              else
                [exception.to_s]
              end
            end
          try_message = "\n#{ordinalize(attempts)} Try error in #{example.location}:\n#{exception_strings.join "\n"} with session #{Capybara.session_name}\n"
          RSpec.configuration.reporter.message(try_message)
        end
      end

      sleep 4
      break if self.attempts >= retry_count
    end
  end
end
