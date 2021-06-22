module Reports
  class Xray
    def initialize(input_file, client_id, client_secret, xray_execution_id = nil)
      @input_file = input_file
      @report_path = File.dirname(input_file)
      @client_id = client_id
      @client_secret = client_secret
      @xray_execution_id = xray_execution_id
      @machine = "#{ENV['USER'].capitalize}'s machine"
      @token = nil
      @json_results = nil
      @specs = nil
      @specs_partition = nil
      @test_plans = nil
      @execution_info = nil
    end

    def process_report
      xray_response = nil
      started_at = Time.new.utc
      raise 'xray_client_id not present' unless @client_id
      raise 'xray_client_secret not present' unless @client_secret
      failed_specs, passed_specs = specs_partition
      passed_tests_array = passed_specs.collect { |data| parse_data(data) }
      failed_tests_array = failed_specs.collect { |data| parse_data(data) }
      info_hash = execution_info
      unless passed_tests_array.empty?
        results = { 'info' => info_hash, 'tests' => passed_tests_array }
        results['testExecutionKey'] = @xray_execution_id if @xray_execution_id
        response = upload_results(results)
        xray_response ||= response
        p "Passed tests response: #{xray_response}"
      end

      tests_count_per_upload = 10
      parts_count = (failed_tests_array.count.to_f / tests_count_per_upload).ceil
      failed_tests_array.each_slice(tests_count_per_upload).each_with_index do |failed_tests, i|
        results = { 'tests' => failed_tests }
        results['testExecutionKey'] = xray_response['key'] if xray_response
        results['info'] = info_hash unless xray_response
        response = upload_results(results)
        xray_response ||= response
        p "Failled tests response: #{response} Part: #{i + 1}/ #{parts_count}"
      end
      completed_at = Time.new.utc
      time_diff = completed_at - started_at # Seconds
      upload_duration = Time.at(time_diff).utc.strftime('%Hh:%Mm:%Ss')
      puts "Results Upload Duration: #{upload_duration}"
      create_email_content
      xray_response
    end

    def add_associated_plans(execution_key = @xray_execution_id)
      raise 'Execution Id not present' unless execution_key
      started_at = Time.new.utc
      total_test_plans = test_plans.count
      sample_spec_data = specs_partition.flatten.last # Trying to get passed data
      sample_test_data = parse_data(sample_spec_data)
      temp_data = { 'testKey' => sample_test_data['testKey'], 'status' => sample_test_data['status'] }
      test_plans.each_with_index do |test_plan, i|
        begin
          test_data = (i + 1) == total_test_plans ? sample_test_data : temp_data
          results = { 'info' => { 'testPlanKey' => test_plan.to_s }, 'tests' => [test_data],
                      'testExecutionKey' => execution_key.to_s }
          response = upload_results(results)
          p "Associated Test Plan: #{test_plan} Response: #{response} Part: #{i + 1}/ #{total_test_plans}"
          p "sample data: #{test_data}"
        rescue
          p "#{test_plan} test plan not uploaded"
        end
      end
      create_email_content
      completed_at = Time.new.utc
      time_diff = completed_at - started_at # Seconds
      upload_duration = Time.at(time_diff).utc.strftime('%Hh:%Mm:%Ss')
      puts "Associated Test Plans Upload Duration: #{upload_duration}"
    end

    def generate_id
      sample_test_plan = '1'
      info_hash = { 'summary' => 'Automation results' }
      results = { 'info' => info_hash, 'tests' => [{ 'testKey' => 'QA-2', 'status' => 'PASSED' }] }
      response = upload_results(results)
      response['key']
    end

    private

    def generate_token
      @token ||= begin
        uri = URI.parse('https://xray.cloud.xpand-it.com/api/v1/authenticate')
        request = Net::HTTP::Post.new(uri)
        request.content_type = 'application/json'
        request.body = { 'client_id' => @client_id, 'client_secret' => @client_secret }.to_json
        req_options = { use_ssl: uri.scheme == 'https' }
        token = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
        token&.body&.delete('"')
      end
    end

    def upload_results(result_hash)
      token = generate_token
      uri = URI.parse('https://xray.cloud.xpand-it.com/api/v1/import/execution')
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      request.body = ''
      request.body << result_hash.to_json
      req_options = { use_ssl: uri.scheme == 'https' }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
      response_body = response&.body
      JSON(response_body)
    rescue
      p "Following results not uploaded, Response: #{response}"
      result_hash['tests'].each do |test|
        p "Case: #{test['testKey']} Status: #{test['status']}"
      end
      nil
    end

    def fetch_screenshots(image_name)
      all_screenshots_path = Dir["#{@report_path}/*.png"].grep(/#{image_name}/)
      return [] if all_screenshots_path.empty?
      # We add only one screenshot per test case
      data = Base64.encode64(File.open(all_screenshots_path[0], 'rb').read)
      content_type = 'image/png'
      filename = all_screenshots_path[0].match(/screenshot.+/).to_s
      [{ 'data' => data, 'filename' => filename, 'contentType' => content_type }]
    end

    def json_results
      @json_results ||= begin
        Reports::Json.parse_essentials("#{@input_file}.json")
      end
    end

    def specs
      @specs ||= json_results[:specs]
    end

    def specs_partition
      @specs_partition ||= specs.partition { |e| e[:status] == 'failed' }
    end

    def test_plans
      @test_plans ||= specs.collect { |a| "QA-#{a[:plan]}" }.uniq
    end

    def execution_info
      result_summary = json_results[:summary]
      time_var = Time.new.utc
      build_env = ENV['JOB_NAME'] || ENV['QA_APP'] || 'Automation'
      build_name = build_env.gsub('Blackbox QA - ', '')
      summary = "Execution results [#{time_var.strftime('%m/%d/%Y')} - #{build_name}]"
      duration = Time.at(result_summary[:duration]).utc.strftime('%Hh:%Mm:%Ss')
      description = "Automation results from Jenkins #{build_name} build.#{ENV['BUILD_URL']} \n Duration: #{duration}"
      browser = 'Chrome'
      @execution_info ||= { 'summary' => summary, 'description' => description, 'testEnvironments' => [browser.capitalize.to_s] }
    end

    def parse_data(data)
      time_var = Time.new.utc
      time = time_var.to_s
      status = data[:status].upcase
      test_key = "QA-#{data[:case]}"
      message = data[:failure_message]
      backtrace = data[:failure_backtrace]
      comment = ''"
        *Status:* #{status}
        *Tested by:* Automation
        *Run Time:* #{data[:run_time]}.
        *Parsed on:* #{@machine} at #{time}
        *Message:* #{message}
        *Backtrace:* #{backtrace}
        "''
      if status == 'FAILED'
        evidences = data[:failure_screenshot] ? fetch_screenshots(data[:failure_screenshot]) : []
        { 'testKey' => test_key, 'comment' => comment, 'status' => status, 'evidences' => evidences }
      else
        { 'testKey' => test_key, 'comment' => comment, 'status' => status }
      end
    end

    def fetch_time_data
      started_at = ENV['START_TIME'] ? Time.parse(ENV['START_TIME']) : Time.new.utc
      completed_at = Time.new.utc
      time_diff = completed_at - started_at # Seconds
      days = (time_diff / (24 * 60 * 60)).to_i
      duration = Time.at(time_diff).utc.strftime("#{days}d:%Hh:%Mm:%Ss")
      [started_at, completed_at, duration]
    end

    def create_email_content
      execution_id = @xray_execution_id
      results_hash = {}
      specs_partition.flatten.reverse.each do |spec|
        results_hash[spec[:case]] = { 'plan' => spec[:plan], 'status' => spec[:status].capitalize }
      end
      started_at, completed_at, duration = fetch_time_data
      content = <<-TEMPLATE
      <html>
        <head>
          <style type="text/css">
          .results {font-size:12px;color:#333333;width:100%;border-width: 1px;border-color: #729ea5;border-collapse: collapse;width: 600px;}
          .results th {font-size:12px;background-color:#acc8cc;border-width: 1px;padding: 8px;border-style: solid;border-color: #729ea5;text-align:left;}
          .results tr {background-color:#d4e3e5;}
          .results tr.passed {background-color:#c0fad8;}
          .results tr.failed {background-color:#faa7b5;}
          .results tr.skipped {background-color:#fbfca9;}
          .results td {font-size:12px;border-width: 1px;padding: 8px;border-style: solid;border-color: #729ea5;}
          .results tr:hover {background-color:#ffffff;}
          </style>
        </head>
        <body>
        <h1>Jenkins Results</h1>
        <h5>Build Link: #{ENV['BUILD_URL']}</h5>
        <h5>Build Id: #{ENV['BUILD_ID']}</h5>
        <h5>Started at: #{started_at}</h5>
        <h5>Completed at: #{completed_at}</h5>
        <h5>Duration: #{duration}</h5>
        <h5>Execution Link: <a href='https://listenfirstmedia.atlassian.net/browse/#{execution_id}'>#{execution_id}<a/></h5>
        <table class="results" border="1">
        <thead><th>S.No</th><th>Test Case</th><th>Test Plan</th><th>Status</th></thead>
        <tbody>
        #{results_hash.each_with_index.collect do |(case_id, data), index|
            generate_email_row(execution_id, case_id, data['plan'], data['status'], index)
          end.join}
        </tbody>
        </table>
        </body>
      </html>
    TEMPLATE
      path = "#{@report_path}/email_content.html"
      File.delete(path) if File.exist?(path)
      File.write(path, content)
    end

    def generate_email_row(execution_id, case_id, plan_id, status, index)
      xray_test_link = "https://listenfirstmedia.atlassian.net/plugins/servlet/ac/com.xpandit.plugins.xray/execution-page?ac.testExecIssueKey=#{execution_id}&ac.testIssueKey=QA-#{case_id}"
      ''"<tr class=#{status.downcase}>
        <td>#{index + 1}</td>
        <td><a href='https://listenfirstmedia.atlassian.net/browse/QA-#{case_id}'>QA-#{case_id}</a></td>
        <td><a href='https://listenfirstmedia.atlassian.net/browse/QA-#{plan_id}'>QA-#{plan_id}</a></td>
        <td><a href=#{xray_test_link}>#{status}</a></td>
        </tr>
      "''
    end
  end
end
