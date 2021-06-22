require 'json'
require 'fileutils'

module Reports

  class Html
    include Reports

    RSpec::Core::Formatters.register self, :start, :example_group_started, :example_started, :message, :example_passed, :example_failed, :example_pending, :start_dump, :dump_summary, :close

    def initialize(stdout)
      @printer = Reports::HtmlProcessor.new("#{output}.html")
    end

    attr_reader :printer

    def start(notification)
      printer.start(notification.count)
    end

    def example_group_started(notification)
      printer.example_group_started(meta_g(notification.group))
    end

    def example_started(notification)
      printer.example_started(meta_e(notification.example))
    end

    def message(notification)
      message = notification.message
      if(message.is_a? Hash)
        @additional_screenshot = File.basename(message[:screenshot])
      end
    end

    def example_passed(notification)
      printer.example_passed(meta_e(notification.example))
    end

    def example_failed(notification)
      printer.example_failed(
        meta_e(notification.example).tap { |meta|
          meta[:failure] = failure(notification, @additional_screenshot)
        }
      )
      @additional_screenshot = nil
    end

    def example_pending(notification)
      printer.example_pending(meta_e(notification.example))
    end

    def start_dump(_notification)
      printer.start_dump
    end

    def dump_summary(notification)
      printer.dump_summary(summary(notification))
    end

    def close(_notification)
      printer.close
    end
  end
end