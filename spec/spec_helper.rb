require "pathname"

require "rspec/core"
require "rspec/expectations"
require "capybara"
require "capybara/dsl"
require "capybara/rspec/matchers"
require "capybara/rspec/features"
require "parallel_tests"
require "selenium-webdriver"

require "capybara-screenshot/rspec"

require "rspec/retry"

require "site_prism"

require "date"
require "byebug"
require "ostruct"
require "logger"
require "csv"

# $VERBOSE = nil # Main reason is to suppress 'Class variable access from top level'
$ERROR_RETRIES = (ENV["ERROR_RETRIES"] || "0").to_i
$ROOT = Pathname.new("#{File.dirname(__FILE__)}/..").realpath.to_s
$LOG = Logger.new(File.join($ROOT, "reports", "automation.log"), "daily")

def load_dir(dir)
  Dir["#{$ROOT}/#{dir}/**/*.rb"].each { |f| require(f) }
end

Capybara.save_path = ENV["ARCHIVE_DIRECTORY"] || "#{$ROOT}/reports"
Capybara::Screenshot.append_timestamp = true
Capybara::Screenshot.register_driver(:webdriver) do |driver, path|
  driver.save_screenshot(path)
  RSpec.world.reporter.message({ screenshot: path })
end

Capybara::Screenshot.register_filename_prefix_formatter(:rspec) do |example|
  plan_id = example.metadata[:plan]
  case_id = example.metadata[:case]
  description = example.description.gsub(/\s/, "_")
  "#{ENV["BUILD_NUMBER"]}screenshot-#{plan_id}-#{case_id}-#{description}"
end

RSpec.configure do |config|
  config.include Capybara::DSL, type: :feature
  config.include Capybara::RSpecMatchers, type: :feature
  config.include Capybara::RSpecMatchers, type: :view

  load_dir("extensions")
  load_dir("lib")
  load_dir("modules")
  load_dir("rspec_support")
  load_dir("sections/common")
  TestBench.configure(config)

  load_dir("sections")
  load_dir("pages")

  config.include HtmlHelper, type: :feature
  config.include DownloadHelper, type: :feature

  # A work-around to support accessing the current example that works in both
  # RSpec 2 and RSpec 3.
  fetch_current_example = RSpec.respond_to?(:current_example) ? proc { RSpec.current_example } : proc { |context| context.example }

  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  # run retry only on features
  # config.around :each do |ex|
  #   meta = ex.metadata
  #   # Capybara.page.driver.browser.manage.window.resize_to(1600, 1200) rescue nil
  #   CapybaraRetry.run_with_retry(ex, $ERROR_RETRIES)
  # end

  config.before do
    if self.class.include?(Capybara::DSL)
      example = fetch_current_example.call(self)
      Capybara.current_driver = Capybara.javascript_driver if example.metadata[:js]
      Capybara.current_driver = example.metadata[:driver] if example.metadata[:driver]
    end
  end

  config.treat_symbols_as_metadata_keys_with_true_values = true
  if TestBench.should_check_for_javascript_errors
    require "capybara-webkit"
    config.filter_run js: :true
  elsif TestBench.should_run_scenarios
    config.filter_run_excluding :js
  else
    config.run_all_when_everything_filtered = true
  end

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
