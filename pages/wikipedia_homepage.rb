module Wikipedia
  class HomePage < SitePrism::Page
    include HtmlHelper
    set_url "https://en.wikipedia.org/wiki/Main_Page"
    element :search_input, "input#searchInput"
    elements :suggestion_results, ".suggestions-result"

    def navigate
      visit(url)
      wait_until_search_input_visible(wait: TestBench.tiny_wait)
      true
    end

    def search(term)
      search_input.set term
      wait_until_suggestion_results_visible(wait: TestBench.tiny_wait)
      press_enter
      true
    end
  end
end
