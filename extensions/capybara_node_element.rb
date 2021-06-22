Capybara::Node::Element.class_eval do
  def click_at(x, y)
    driver.browser.action.move_to(native).move_by(x, y).click.perform
  end
end
