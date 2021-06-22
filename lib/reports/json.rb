require 'json'
require 'fileutils'

module Reports
  class Json
    include Reports

    RSpec::Core::Formatters.register self, :start, :example_group_started, :example_group_finished, :example_passed, :example_failed, :example_pending, :message, :close, :dump_summary

    # TEST_ENV_NUMBER will be empty for the first one, then start at 2 (continues up by 1 from there)
    def initialize(stdout)
      # do nothing
    end

    attr_reader :files

    def start(_notification)
      @files = []
      @details = { specs: [] }
    end

    def example_group_started(notification)
      group = g(notification.group)
      if files.empty?
        @failed = false
        @details[:specs] << group
      else
        files.last.groups << group
      end
      files << group
    end

    def example_group_finished(_notification)
      g = files.pop
      g.failed! if @failed
    end

    def example_passed(passed)
      current.examples << e(passed.example)
    end

    def example_failed(notification)
      current.examples << e(notification.example).tap do |fe|
        fe.failed!(failure(notification, @additional_screenshot))
      end
      @additional_screenshot = nil
      @failed = true
    end

    def example_pending(pending)
      current.examples << e(pending.example)
    end

    def message(notification)
      message = notification.message
      if message.is_a? Hash
        @additional_screenshot = File.basename(message[:screenshot])
      end
    end

    def close(_notification)
      File.write("#{output}.json", JSON.pretty_generate(@details))
    end

    def dump_summary(notification)
      @details[:summary] = summary(notification)
    end

    def self.aggregate(files, output)
      details = { specs: [], summary: Hash.new { |h, k| h[k] = 0 } }
      files.each do |file|
        json = JSON.parse(File.read(file))
        details[:specs].concat(json['specs'])
        json['summary'].each { |k, v| details[:summary][k] += v }
      end
      File.write("#{output}.json", JSON.pretty_generate(details))
    end

    def self.parse(file)
      symbolize_keys(JSON.parse(File.read(file)))
    end

    def self.update_primary_results(primary_json, secodary_json)
      f_specs = {}
      parse_tree(secodary_json[:specs]) do |meta|
        f_specs[meta[:case]] = meta
      end
      parse_tree(primary_json[:specs]) do |meta|
        meta.replace(f_specs[meta[:case]]) if f_specs[meta[:case]]
      end
      primary_json[:summary][:failure_count] = secodary_json[:summary][:failure_count]
      primary_json
    end

    def self.parse_essentials(file)
      keys = %i[plan case description priority run_priority run_time status file_path failure_message failure_backtrace failure_screenshot]
      json = parse(file)
      summary = json[:summary]
      specs = []
      parse_tree(json[:specs]) do |meta|
        meta[:failure_message] = meta.dig(:failure, :message)&.gsub(/[\n\r]+/, '|')
        meta[:failure_backtrace] = meta.dig(:failure, :backtrace)&.gsub(/[\n\r]+/, '|')
        meta[:failure_screenshot] = meta.dig(:failure, :screenshot)&.gsub(/[\n\r]+/, '|')
        specs << meta.select { |k, _v| keys.include?(k) }
      end
      { summary: summary, specs: specs }
    end

    private

    def self.symbolize_keys(hash)
      hash.each_with_object({}) do |(k, v), hash|
        hash[k.to_sym] = v.is_a?(Hash) ? symbolize_keys(v) : (v.is_a?(Array) ? v.map { |o| symbolize_keys(o) } : v)
      end
    end

    def self.parse_tree(specs, &block)
      specs.each do |item|
        if item[:type] == 'group'
          parse_tree(item[:children], &block)
        elsif item[:type] == 'example'
          block.call(item)
        end
      end
    end

    def current
      files.last
    end
  end
end
