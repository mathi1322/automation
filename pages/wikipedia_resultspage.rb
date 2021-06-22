module Wikipedia
  class ArticlePage < SitePrism::Page
    element :header, "h1#firstHeading"
    element :article_content, "div#bodyContent"

    def wait_until_loaded
      wait_until_header_visible(wait: TestBench.tiny_wait)
      wait_until_article_content_visible(wait: TestBench.tiny_wait)
    end
  end
end
