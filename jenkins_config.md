
export TEST_PLAN_FILTERS=`be ruby -W0 ./bin/blackbox.rb plans_for_build 'Blackbox QA - Stable'`
export RUN_BY_PRIORITIES=true

Upgrade Chrome
  Chrome update
  TODO: <<need to update>>
  Update driver
  1) Goto http://chromedriver.storage.googleapis.com/
  2) Find the appropriate version
  3) Add it to jenkins chromedriver-update <<version>>
