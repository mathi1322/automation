require "yaml"
require_relative "./config/webdriver_run"

class TestBench
  def initialize(env)
    @env = env
  end

  def config
    @config ||= begin
        hash = file
        symbolize_keys(hash)
      end
  end

  def file
    environment = ENV["QA_TEST_ENV"] || "dev"
    p "On #{environment} environment"

    config_hash = YAML.safe_load(File.read("#{ENV["HOME"]}/.qarc")) rescue {}
    config_hash["application"] = config_hash[environment]
    config_hash
  end

  class << self
    def set_environment(env)
      @@instance = TestBench.new(env)
    end

    def method_missing(method_id)
      @@instance.config[method_id]
    end

    def mini_wait; 2 end
    def tiny_wait; 5 end
    def little_wait; 10 end
    def short_wait; 20 end
    def long_wait; 40 end
    def standard_wait; 60 end
    def considerable_wait; 100 end
    def epic_wait; 200 end
    def huge_wait; 500 end
    def default_runtype; :all_tests end
    def default_browser; :chrome end
    
    def envtype
      (ENV["envtype"] || TestBench.default_envtype).to_sym
    end

    def runtype
      (ENV["runtype"] || TestBench.default_runtype).to_sym
    end

    def browser
      (ENV["BROWSER"] || TestBench.default_browser).to_sym
    end

    def should_check_for_javascript_errors
      runtype == :all_tests || runtype == :js_errors_only
    end

    def should_run_scenarios
      runtype == :all_tests || runtype == :scenarios_only
    end

    def configure(_config)
      TestBench.set_environment(:dev)
      ::WebdriverRun.configure
      # Capybara.app_host = TestBench.homepage
    end

    def log_event(msg, status: nil, exception: nil, started_at: nil)
      file_path = "#{Dir.pwd}/reports/#{ENV["BUILD_NUMBER"]}/index.tsv"
      metadata = RSpec.current_example.metadata
      session_name = Capybara.session_name
      begin
        Capybara.current_window.handle
      rescue
        current_session = (session_name.to_s + "_1").to_sym
        ENV["CURRENT_SESSION"] = current_session.to_s
        Capybara.session_name = current_session
      end
      window = Capybara.current_window.handle
      # Capybara.page.driver.browser.manage.window.resize_to(1600, 1200)
      url = Capybara.current_url
      duration = started_at ? Time.now - started_at : nil
      row = <<~HEREDOC
        #{Time.now}\t#{msg}\t#{status}\t#{window}\t#{session_name}\t#{metadata[:case]}\t\
        #{metadata[:plan]}\t#{url}\t#{duration}\t#{exception}\t#{metadata[:description]}
      HEREDOC
      columns = <<~HEREDOC
        CURRENT_TIME\tEVENT\tSTATUS\tWINDOW\tSESSION_NAME\tTEST CASE\tTEST PLAN\tURL\
        \tDURATION\tERROR DESCRIPTION\tDESCRIPTION
      HEREDOC
      File.write(file_path, columns) unless File.exist?(file_path)
      File.open(file_path, "a") { |f| f.write(row) }
    end
  end

  private

  def symbolize_keys(hash)
    hash.each_with_object({}) do |(k, v), hash|
      hash[k.to_sym] = v.is_a?(Hash) ? symbolize_keys(v) : v
    end
  end
end
