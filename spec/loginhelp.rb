class LoginPage < SitePrism::Page
  set_url 'https://explorer.stage.lfmprod.in/#dashboard/start'
	element :user_name_elem, '#signInFormUsername'
	element :password_elem, '#signInFormPassword'
	element :sign_in_button, 'input.btn.btn-primary.submitButton-customizable'
	element :menu, 'div.menu-grid'
	element :brandlist, 'tbody'
	element :number, 'div.dataTables_info'
	element :search, 'input.form-control'
  
	def login(mail, pass)
		user_name_elem.set(mail)
		password_elem.set(pass)
		sign_in_button.click
		sleep 30
  end
  
	def click_item(name)
		item = menu.find_all('div.menu-item').find{|x| x.find('div.item-label').text == name }
		item.click
  	end
  
  def brand?(name)
	  brandlist.find_all('td.brand-metadata').any?{|x| x.find('span.title-span').text == name }
  end

  def total_count
    number.text.gsub(/[^\d]/, '')[1].to_i
  end

  def display_count
    number.text.gsub(/[^\d]/, '')[0].to_i
  end

  def title_count
    brandlist.find_all('td.brand-metadata').count
  end

  def filter_by(name)
	  search.set(name)
  end

  def clear_filter
    search.set('')
  end
  def title
    brandlist.find('span.title-span').text
  end

end