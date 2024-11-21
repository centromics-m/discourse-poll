


it 'Click Hamber Menu' do
  wait = Selenium::WebDriver::Wait.new(timeout: 10)

  wait.until do
    elements = @driver.find_elements(class: 'd-modal__backdrop')
    elements.empty?
  end

  button = wait.until do
    element = @driver.find_element(id: 'toggle-hamburger-menu')
    element if element.displayed? && element.enabled?
  end

  # 클릭하기
  button.click
end

it 'Go to Admin' do
  hamber_menu=@driver.find_element(id: 'sidebar-section-content-community')
  go_admin_menu=hamber_menu.find_element(css: "[href='/admin']")

  go_admin_menu.click
end


