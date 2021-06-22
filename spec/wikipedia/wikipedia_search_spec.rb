describe "Google", type: :feature do
  context "Initial Page", :integration do
    let(:home_page) { Wikipedia::HomePage.new }
    let(:results_page) { Wikipedia::ArticlePage.new }

    it "should have an input field", plan: "1", case: "1" do
      home_page.navigate
      expect(home_page).to have_search_input
    end

    it "should have correct result page", plan: "1", case: "3" do
      home_page.navigate
      home_page.search "Fish"
      results_page.wait_until_loaded
      expect(results_page).to have_header
      expect(results_page).to have_article_content
      expect(results_page.article_content.text).to match(/fish/i)
    end
  end
end
