require 'byebug'
describe "the signin process", type: :feature do
  it "signs me in" do
   dashboard_url = 'https://explorer.lfmdev.in/#dashboard/start'
   visit dashboard_url
    within("div.modal-body") do
      fill_in 'signInFormUsername', with: 'turneruser@turner.com'
      fill_in 'signInFormPassword', with: 'turnertest'
      find("[value='Sign in']").click
    end
   sleep(20)
   expect(current_url).to match(dashboard_url)
  end
end
# describe "Google", type: :feature do
#   context "Initial Page", :integration do
#     let(:home_page) { Wikipedia::HomePage.new }
#     let(:results_page) { Wikipedia::ArticlePage.new }

#     it "should have an input field", plan: "1", case: "1" do
#       home_page.navigate
#       expect(home_page).to have_search_input
#     end

#     it "should have correct result page", plan: "1", case: "3" do
#       home_page.navigate
#       home_page.search "Fish"
#       results_page.wait_until_loaded
#       expect(results_page).to have_header
#       expect(results_page).to have_article_content
#       expect(results_page.article_content.text).to match(/fish/i)
#     end
#   end
# end
