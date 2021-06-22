# System Configuration
### Prerequirement
- rbenv
- Ruby 2.5.1
- Bundler
- For Chrome, use latest version `(current: 72.0)`
- For Firefox, use latest version `(current: 65.0)`

# Setup
```
sudo apt-get -y install libqt5webkit5-dev libqt4-dev libqtwebkit-dev
cd PROJECT_FOLDER
bundle install
touch ~/.qarc
```

# Toggle Test Environment
#### Dev (default)
```
export QA_TEST_ENV="dev"
export QA_TEST_ENV="stage"
```

# Test Cases Execution
 - Executing all Test Cases
```
rspec -fd
```
- Executing a Single Test Case
```
rspec -fd --tag case:<<test-case-id>>
rspec -fd --tag case:2
```
- Executing a Test plan
```
rspec -fd --tag plan:14
```
- Executing multiple Test Cases
```
export TEST_CASE_FILTERS=<<test-case-id>>,<<test-case-id>>,<<test-case-id>>
bundle exec parallel_rspec -m 2 spec/*
```
- Executing multiple Test Plans
```
export TEST_PLAN_FILTERS=<<test-plan-id>>,<<test-plan-id>>,<<test-plan-id>>
bundle exec parallel_rspec -m 2 spec/*
```
- To set error retries count. It is used to rerun the failed test cases given number of times.
```
export ERROR_RETRIES=<<Numerical value>>
bundle exec parallel_rspec -m 2 spec/*
```
Note: Increasing retries count might give better results. But it will increase the run time duration.
- Exporting Report to a HTML File
```
bundle exec parallel_rspec -m 2 spec/*
bundle exec parallel_rspec -m 2 spec/* && bundle exec ruby bin/blackbox.rb aggregate './output/' './reports/'
```
- Exporting Report to a CSV File
```
bundle exec parallel_rspec -m 2 spec/*
bundle exec parallel_rspec -m 2 spec/* && bundle exec ruby bin/blackbox.rb csv './output/' './reports/'
```

#	Running tests in a specific browser
Browsers available are `chrome`, `firefox`, `chrome_headless`, `firefox_headless`. By default, chrome is used.
```
export BROWSER=chrome_headless; rspec --tag plan:1
```

# Running tests in parallel
Now have included parallel tests
1. Executing all tests cases
```
bundle exec parallel_rspec spec/
```
2. Executing specific test case
```
export SPEC_OPTS='--tag case:<<test-case-id>>'; bundle exec parallel_rspec spec/
```
3. Increase number of threads
```
bundle exec parallel_rspec spec/ -m 2
```

# Viewing Test logs
  For Single Run
    logs/test-report.html
  For Parallel Run
    Report generated for each spec
```
output/test-result1.html
output/test-result2.html
output/test-result3.html
output/test-result4.html
```

# Jenkins Configuration
###Install Plugins:
- HTML publisher
- git

### Ruby Version:
- 2.5.1 (Select 'Ignore Local Version' using Advanced Options)
- Preinstall gem list (bundler, rake)

### Jenkins Shell Commands Example
```
echo "Current shell is $SHELL ($0)"
echo "Who Am I: `whoami`"

export PATH=$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH
export archive_zip_path="reports_$BUILD_NUMBER.zip"
echo "Path is: $PATH"

export START_TIME=`date -u`
export QA_TEST_ENV='dev'
export QA_APP='QA Automation'

# export TEST_PLAN_FILTERS=`echo $TEST_PLANS`
# export TEST_CASE_FILTERS=`echo $TEST_CASES`
export BROWSER=`echo $BROWSER`;
export ERROR_RETRIES=`echo $RETRIES`;

mkdir -p "./reports/${BUILD_NUMBER}"
mkdir -p "./output/${BUILD_NUMBER}"

export REPORTS_DIRECTORY="./output/${BUILD_NUMBER}"
export REPORTS_FILE="report"
export ARCHIVE_DIRECTORY="${PWD}/reports/${BUILD_NUMBER}"

rbenv versions
ruby -v
bundle install

{
  bundle exec parallel_rspec -m 2 spec/* && bundle exec ruby bin/blackbox.rb aggregate $REPORTS_DIRECTORY "${ARCHIVE_DIRECTORY}/${REPORTS_FILE}"
} || 
{ bundle exec ruby bin/blackbox.rb aggregate $REPORTS_DIRECTORY "${ARCHIVE_DIRECTORY}/${REPORTS_FILE}" && zip -r $archive_zip_path "reports/$BUILD_NUMBER"; echo 'rspec failed' ; exit 1; } 

```

### Archive Artifacts:
Files to Archive `web/blackbox/reports/*`

### Publish HTML Reports
- HTML directory `web/blackbox/reports`
- Index Pages `report.html`

# Security Policy:
Edit /etc/default/jenkins to include following
```
Content Security Policy
CSP="img-src 'self'; style-src 'unsafe-inline'; script-src: 'unsafe-inline'"
append to JAVA_ARGS
-Dhudson.model.DirectoryBrowserSupport.CSP=\"$CSP\""
```
