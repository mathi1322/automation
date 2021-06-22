module HtmlHelper
  def parse_table(table)
    headers = table.all("thead>tr>th").map(&:text)
    table.all("tbody>tr").map do |row|
      values = row.all("td").map(&:text)
      Hash[headers.zip(values)]
    end
  end

  def headers(table)
    table.all("thead>tr>th").map { |col| col.text.downcase }
  end

  def vertically_aligned?(object_1, object_2, x_variance = 0)
    difference = get_xposition(object_1) - get_xposition(object_2)
    difference.abs <= x_variance
  end

  def scroll_to(element) # View Scroll
    script = <<-JS
      arguments[0].scrollIntoView(true);
    JS
    element = element.first if element.is_a?(Enumerable)
    element = element.native if element.respond_to?(:native)
    Capybara.current_session.driver.browser.execute_script(script, element)
  end

  # does not work in popup..
  def scroll(element, x_modification = 0, y_modification = 0) # window Scroll
    x = get_xposition(element) + x_modification
    y = get_yposition(element) - 100 + y_modification
    script = <<-JS
      window.scrollTo(#{x},#{y});
    JS
    Capybara.current_session.driver.browser.execute_script(script)
  end

  def page_obj
    page.is_a?(Capybara::Node::Element) ? parent_page.page : page
  end

  def click_element(element, x_modification, y_modification)
    page_obj.driver.browser.action.move_to(element.native).move_by(x_modification, y_modification).click.perform
  end

  def get_position(element)
    x = get_xposition(element)
    y = get_yposition(element)
    { x: x, y: y }
  end

  def press_enter
    page_obj.driver.browser.action.send_keys(:enter).perform
    true
  end

  def press_backspace
    page_obj.driver.browser.action.send_keys(:backspace).perform
    true
  end

  def get_style(element, style)
    if element.respond_to?(:native)
      element.native.style(style)
    else
      element.root_element.native.style(style) # if section is passed
    end
  end

  def get_hex_color_code(element, style)
    get_style(element, style).color_to_hex
  end

  def get_parsed_element(element, selector = nil)
    element_content = element.native["outerHTML"]
    html = Nokogiri::HTML(element_content)
    if selector
      html.at_css(selector)
    else
      html
    end
  end

  def get_text(element, selector = nil)
    get_parsed_element(element, selector).text
  end

  private

  def get_xposition(element)
    if element.respond_to?(:native)
      element.native.location.x
    else
      element.root_element.native.location.x # if section is passed
    end
  end

  def get_yposition(element)
    if element.respond_to?(:native)
      element.native.location.y
    else
      element.root_element.native.location.y # if section is passed
    end
  end
end
