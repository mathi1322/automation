require "fileutils"
require "ostruct"

module DownloadHelper
  def self.path
    id = ENV["TEST_ENV_NUMBER"].nil? ? 1 : ENV["TEST_ENV_NUMBER"]
    "#{$ROOT}/temp/downloaded_file/#{id}"
  end

  def set_new_download_path # current downloaded file set to corresponding tests path
    test_number = RSpec.current_example.metadata[:case]
    browser_obj = self.respond_to?("parent") ? self.parent.page.driver.browser : self.page.driver.browser
    if browser_obj.browser.to_s.include?("firefox")
      DownloadHelper.path
    else
      browser_obj.download_path = "#{$ROOT}/temp/downloaded_file/#{test_number}"
    end
  end

  def clean_download_path
    dirname = set_new_download_path
    FileUtils.rm_rf(dirname) if File.directory?(dirname)
  end

  def downloaded_files
    Dir[File.join(set_new_download_path, "*")]
  end

  def downloaded_file
    downloaded_files.sort.first
  end

  def wait_until_download
    SitePrism::Waiter.wait_until_true(TestBench.long_wait) do
      downloaded?
    end
    sleep 10 # TODO: add siteprism waiter
  rescue
    raise "File not dowloaded"
  end

  def downloaded?
    !downloading? && downloaded_files.any?
  end

  def downloading?
    downloaded_files.grep(/\.part$|\.crdownload$/).any?
  end

  def extension
    File.extname(downloaded_file)[1..-1]
  end

  def process_file(file, opts = {})
    options = { skip_first_rows: 0 }.merge(opts)
    file_array = File.readlines(file)
    meta_content = file_array[0...(options[:skip_first_rows] - 1)]
    table_content = file_array.drop(options[:skip_first_rows])
    table_content.pop if options[:skip_last_row]
    f = File.new("#{set_new_download_path}/temp.#{extension}", "w")
    File.open(f, "w") { |file| table_content.each { |value| file.write(value) } }
    { file_path: f.path, meta_data: meta_content }
  end

  def export_column_headers(file, opts = {})
    options = { skip_first_rows: 0 }.merge(opts)
    file_array = File.readlines(file).drop(options[:skip_first_rows])
    headers = file_array[0].delete("\n").strip
    headers
  end

  FileUtils.mkdir_p(path)
end

RSpec.configure do |config|
  config.before(:each) do
    clean_download_path
  end
  config.after(:each) do
    clean_download_path
  end
end
