require "webdrivers/chromedriver"
require "webdrivers/geckodriver"

class WebdriverRun
  def self.configure
    client = Selenium::WebDriver::Remote::Http::Default.new
    client.open_timeout = 120
    client.read_timeout = 120
    Capybara.register_driver :webdriver do |app|
      if %i[chrome chrome_headless].include? TestBench.browser
        Webdrivers::Chromedriver.update

        if TestBench.browser == :chrome
          puts "Using Chrome"
          caps = Selenium::WebDriver::Remote::Capabilities.chrome('goog:loggingPrefs': { browser: "ALL" })
          profile = Selenium::WebDriver::Chrome::Profile.new
          profile["profile.content_settings.popups"] = 0
          profile["profile.content_settings.exceptions.automatic_downloads.*.setting"] = 1
          profile["download.prompt_for_download"] = false
          profile["download.default_directory"] = DownloadHelper.path
          Capybara::Selenium::Driver.new(app, browser: TestBench.browser, http_client: client, profile: profile, desired_capabilities: caps)
        else
          puts "Using Chrome Headless"
          caps = Selenium::WebDriver::Remote::Capabilities.chrome('goog:loggingPrefs': { browser: "ALL" })
          options = Selenium::WebDriver::Chrome::Options.new(
            args: %w[headless disable-gpu disable-popup-blocking disable-dev-shm-usage],
            prefs: { "download.default_directory" => DownloadHelper.path },
          )

          # The following options previously used have not been implemented.
          # If necessary, find a way to implement them

          # profile = Selenium::WebDriver::Chrome::Profile.new
          # profile['profile.content_settings.popups'] = 0
          # profile['profile.content_settings.exceptions.automatic_downloads.*.setting'] = 1
          # profile['download.prompt_for_download'] = false

          Capybara::Selenium::Driver.new(
            app,
            browser: :chrome,
            http_client: client,
            options: options,
            desired_capabilities: caps,
          ).tap do |driver|
            driver.browser.download_path = DownloadHelper.path
          end
        end
      elsif %i[firefox firefox_headless].include? TestBench.browser
        Webdrivers::Geckodriver.update

        options = Selenium::WebDriver::Firefox::Options.new
        options.add_preference("download.prompt_for_download", false)
        options.add_preference("profile.content_settings.exceptions.automatic_downloads.*.setting", 1)
        options.add_preference("profile.content_settings.popups", 0)

        options.add_preference("browser.download.dir", DownloadHelper.path)
        options.add_preference("browser.download.folderList", 2)
        options.add_preference("browser.helperApps.neverAsk.saveToDisk", "text/csv,text/tsv,application/pdf,application/doc,application/docx,image/jpeg,application/octet-stream doc xls pdf txt")
        # profile.native_events = true

        if TestBench.browser == :firefox
          puts "Using Firefox"
        else
          puts "Using Firefox Headless"
          options.headless!
        end

        Capybara::Selenium::Driver.new(
          app,
          browser: :firefox,
          http_client: client,
          options: options,
        )
      end
    end
    Capybara.javascript_driver = :webdriver
    Capybara.default_driver = :webdriver
    # we call wait_until_loaded before each test so the test would run only after load. (default wait was 10s)
    # Otherwise wherever we call has_<element>? the test would wait 10 seconds which is unnecessary
    # Alternate approach is to give wait at all has_<element>? methods like has_button?(wait: 5)
    # but that would look messy in our spec files.
    # refer: https://blog.tomoyukikashiro.me/post/things-to-be-aware-of-when-change-capybara_default_wait_time
    Capybara.default_max_wait_time = 0
    # Capybara.page.driver.browser.manage.window.resize_to(1600, 1200)
  end
end
