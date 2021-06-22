require 'nokogiri'
require 'yaml'
class ReportProcessor
  class << self
    def xray(report_file, output_file)
      machine = "#{ENV['USER'].capitalize}'s machine"

      doc = Nokogiri::HTML::DocumentFragment.parse(File.read(report_file))

      reported_time = doc.text.scan(/(?<=Report Time: <strong>)(.*)(?=<\/strong)/).flatten&.first

      failed_test_cases = get_test_cases(doc.css('span.failed_spec_name'))
      pending_test_cases = get_test_cases(doc.css('span.not_implemented_spec_name'))
      passed_test_cases = get_test_cases(doc.css('span.passed_spec_name')) - failed_test_cases - pending_test_cases

      tests_array = []

      time = "#{Time.new.utc}"

      passed_test_cases.each do |test_case|
        tests_array << { 'testKey' => "QA-#{test_case}", 'comment' => "Status: Pass \n \
      Tested by: Automation \n Reported Time: #{reported_time} \nParsed on: #{machine} at #{time}", 'status' => 'PASSED' }
      end

      failed_test_cases.each do |test_case|
        tests_array << { 'testKey' => "QA-#{test_case}", 'comment' => "Status: Fail \n \
      Tested by: Automation \n Reported Time: #{reported_time} \nParsed on: #{machine} at #{time}", 'status' => 'FAILED' }
      end

      pending_test_cases.each do |test_case|
        tests_array << { 'testKey' => "QA-#{test_case}", 'comment' => "Status: Pending \n \
      Status by: Automation \n Reported Time: #{reported_time} \nParsed on: #{machine} at #{time}", 'status' => 'TO DO' }
      end

      results = { 'tests' => tests_array }
      File.write(output_file, results.to_json)
    end


    def details(html_path)
      meta_regex = /\(.*\)/
      doc = Nokogiri::HTML::DocumentFragment.parse(File.read(html_path))
      examples = doc.css('dd.example')
      headers = %s(test_plan test_case example_name case_priority run_duration status failed_reason)

      examples.map do |example| 
        status = 'passed'
        desc_node = example.css('span.passed_spec_name')
        if(desc_node.nil? || desc_node.length == 0)
          desc_node = example.css('span.failed_spec_name')
          status = 'failed'
        end
        desc_text = desc_node.text
        meta_text = meta_regex.match(desc_text)
        duration = example.css('span.duration')&.text&.gsub('s', '')
        if(meta_text && meta_text[0])
          mhash = Hash[meta_text[0].gsub(/[\(\)\s\']/, '').split(',').map{|s| s.split(':')}]
          hash = {
            case: mhash['TestCase'],
            plan: mhash['TestPlan'],
            priority: mhash['Priority'],
            plan_priority: mhash['PlanPriority'],
            duration: duration,
            description: desc_text.gsub(meta_regex,'').gsub(/-/, '').strip,
            status: status
          }
          if status == 'failed'
            hash[:stacktrace] = example.css('div.backtrace > pre').text.strip.gsub(/\n/, '|')
            hash[:error_message] = example.css('div.message > pre').text.strip.gsub(/\n/, '|')
          end
          hash
        else
          raise "Unable to find meta_text for #{example.to_html}, #{{duration: duration, description: desc_text.gsub(meta_regex).strip, status: status}}"
        end
      end
    end

    def aggregate(files, output_file)
      compiled_report = Nokogiri::HTML::DocumentFragment.parse(File.read("#{Dir.pwd}/rspec_report.template"))
      results_node = compiled_report.css('.results').first

      report_title = (ENV['QA_APP'] || 'QA')
      report_title = report_title.capitalize unless(report_title == 'QA')   #to capitalize title name

      total_count = 0
      failure_count = 0
      pending_count = 0
      example_id = 0
      report_id = 0

      files.each { |path|
        doc = Nokogiri::HTML::DocumentFragment.parse(File.read(path))
        total_count += doc.css('dd.example').count
        failure_count += doc.css('span.failed_spec_name').count
        pending_count += doc.css('dd.not_implemented').count
        report_id += 1

        subreport_data = <<-HEADER
          <dl style="margin-left: 15px">
            <dt style="background-color: black;color: white">
              Report ##{report_id}
              <span class="run-metric">
                  Total: #{doc.css('dd.example').count},
                  Failures: #{doc.css('span.failed_spec_name').count},
                  Pending: #{doc.css('dd.not_implemented').count}
              </span>
            </dt>
          </dl>
        HEADER
        subreport_frag = Nokogiri::HTML::DocumentFragment.parse(subreport_data)
        subreport = results_node.add_child(subreport_data)
        subreport = results_node.css('dl').last
        doc.css('div.results div.example_group').each { |example|
          example_id += 1
          if(example.css('dd.failed').count > 0)
            modified_frag = example.to_html.gsub(/example_group_\d+/, "example_group_#{example_id}")
            example = Nokogiri::HTML::DocumentFragment.parse(modified_frag)
          else
            example.attributes["id"].value = "example_group_#{example_id}"
          end
          subreport.add_child(example)
        }
      }


      summary_template = <<-TEMPLATE
      <script type="text/javascript">document.getElementById('report_time').innerHTML = "Report Time: <strong>%{report_time}</strong>";</script>
      <script type="text/javascript">document.getElementById('test_env').innerHTML = "<strong>%{test_environment}(%{app_url})</strong>";</script>
      <script>document.getElementById('test_env').href = "%{app_url}";</script>
      <script type="text/javascript">document.getElementById('report_title').innerHTML = "<strong>%{report_title} Results</strong>";</script>
      <script type="text/javascript">document.getElementById('duration').innerHTML = "Finished in <strong>%{duration} seconds</strong>";</script>
      <script type="text/javascript">document.getElementById('totals').innerHTML = "%{total} examples, %{failure_count} failures, %{pending_count} pending";</script>
      TEMPLATE
      summary = summary_template % {duration: 0, app_url: app_url , report_title: report_title , total: total_count, failure_count: failure_count, pending_count: pending_count, report_time: Time.now, test_environment: environment.capitalize}
      results_node.add_child(Nokogiri::HTML::DocumentFragment.parse(summary))

      File.write(output_file, compiled_report.to_html)
    end

    private
    def environment
      @environment ||= (ENV['QA_TEST_ENV'] || 'dev')
    end

    def app_url
      qa_app = (ENV['QA_APP'] || 'explorer')
      config['application'][qa_app]
    end

    def config
      config ||= YAML.load(File.read("#{ENV['HOME']}/.lfmrc_qa"))
    end

    def get_test_cases(doc, type)
      elements = doc.css("dd.example.#{type.to_s}")
      a = []
      elements.each do |e|
        test_case = e.text.scan(/(?<=Case:')(\d+)(?=')/).flatten.first
        plan = e.text.scan(/(?<=Plan:')(\d+)(?=')/).flatten.first
        priority = e.text.scan(/(?<=Priority:')(\d+)(?=')/).flatten.first
        time = e.text.scan(/(\d+[.]\d+)/).flatten.first
        backtrace =  e.text.scan(/([a-z]\w+\/\w+\.rb\:\d+)/).flatten.first
        next unless test_case
        a << { priority: priority, plan: plan,test_case: test_case, backtrace: backtrace, time: time }
      end
      a
    end

    def aggregate_test_case_duration(hash_of_case)
      cases = hash_of_case.flatten.group_by{|k| k[:test_case]}.keys
      duration = hash_of_case.flatten.group_by{|k| k[:test_case]}.map{|k, v| v.map{|val| val[:time].to_f}.sum/60}
      Hash[cases.zip(duration)]
    end

  end
end
