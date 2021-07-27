require 'byebug'
require_relative './loginhelp'
describe 'Login basics' do
  context "User log in" do
    it 'clicking', type: :feature do
      sign = LoginPage.new
      sign.load
      sleep 20
      sign.login('turneruser@turner.com', 'turnertest')
      expect(sign.current_url).to eq(set_url)
      sign.click_item('Brands')  
      sleep 20
      expect(sign.brand?('Full Frontal with Samantha Bee')).to eq true
      expect(sign.display_count).to eq 6
      expect(sign.total_count).to eq 6
      expect(sign.title_count).to eq 6
      sign.filter_by('Full Frontal with Samantha Bee')
      sleep 5
      expect(sign.display_count).to eq 1
      expect(sign.total_count).to eq 6
      expect(sign.title).to eq('Full Frontal with Samantha Bee')
      sign.clear_filter
      expect(sign.display_count).to eq 6
      expect(sign.total_count).to eq 6
      expect(sign.title_count).to eq 6
    end
  end
end