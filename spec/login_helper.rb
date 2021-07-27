require_relative './loginhelp'
module LoginHelper
  class LoginPage < SitePrism::Page
    set_url 'https://explorer.stage.lfmprod.in/#dashboard/start'
	  element :user_name_elem, '#signInFormUsername'
	  element :password_elem, '#signInFormPassword'
	  element :sign_in_button, 'input.btn.btn-primary.submitButton-customizable'
  
    def login(mail, pass)
		  user_name_elem.set(mail)
		  password_elem.set(pass)
		  sign_in_button.click
		  sleep 30
    end
    
  end
end
    