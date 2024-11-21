# frozen_string_literal: true

require 'selenium-webdriver'
require 'rspec'
require 'json'

def load_credentials(file_path)
  file = File.read(file_path)
  JSON.parse(file)
end

def random_string()
  charset = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

  # 길이가 10인 랜덤 문자열 생성
  random_string = Array.new(10) { charset.sample }.join
end

RSpec.describe 'Google Search' do
  before(:all) do
    options = Selenium::WebDriver::Options.chrome
    options.add_option(:detach, true) # 이 옵션을 추가
    @driver = Selenium::WebDriver.for :chrome, options: options
  end

  after(:all) do
  #  @driver.quit
  end

  it 'Page Working' do
    credentials_file = 'credentials.json'
    credentials = load_credentials(credentials_file)

    @driver.navigate.to credentials['host']

    login_go_button = @driver.find_element(class: 'login-button')
    login_go_button.click

    username_field=@driver.find_element(id: 'login-account-name')
    password_field= @driver.find_element(id: 'login-account-password')

    username = credentials['username']
    password = credentials['password']

    username_field.send_keys(username)
    password_field.send_keys(password)

    login_button = @driver.find_element(id: 'login-button')
    login_button.click

    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    admin_go_button = wait.until { @driver.find_element(id: 'toggle-hamburger-menu') }
    expect(admin_go_button.displayed?).to be true
  end

  it 'Go Category' do
    wait = Selenium::WebDriver::Wait.new(timeout: 10)

    wait.until do
      elements = @driver.find_elements(class: 'd-modal__backdrop')
      elements.empty?
    end

    poll_category_more = wait.until do
      element = @driver.find_element(class: 'poll-category-more')
      element if element.displayed? && element.enabled?
    end

    go_link=poll_category_more.find_element(css: ':first-child')
    go_link.click
  end

  it 'Create Topic Open' do
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    create_topic = wait.until do
      element = @driver.find_element(id: 'create-topic')
      element if element.displayed? && element.enabled?
    end

    create_topic.click

    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    d_editor = wait.until do
      element = @driver.find_element(class: 'd-editor')
      element if element.displayed? && element.enabled?
    end


    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    reply_title = wait.until do
      element = d_editor.find_element(id: 'reply-title')
      element if element.displayed? && element.enabled?
    end

    reply_title.clear
    reply_title.send_keys('이것은 제목입니다. 그냥 좀 입력되라 '+random_string)

    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    reply_content = wait.until do
      element = d_editor.find_element(class: 'd-editor-input')
      element if element.displayed? && element.enabled?
    end

    reply_content.clear
    reply_content.send_keys('good good good~!

')

    d_editor_button_bar=d_editor.find_element(class: 'd-editor-button-bar')
    option_menu=d_editor_button_bar.find_element(class: 'toolbar-popup-menu-options')

    option_menu.click
  end

  it 'Create Poll Open' do
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    select_kit_collection = wait.until do
      element = @driver.find_element(class: 'select-kit-collection')
      element if element.displayed? && element.enabled?
    end

    poll_menu=select_kit_collection.find_element(css: ':nth-child(4)')
    poll_menu.click
  end

  it 'Poll Option Fill' do

    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    poll_options = wait.until do
      element = @driver.find_element(class: 'poll-options')
      element if element.displayed? && element.enabled?
    end

    poll_option_add=poll_options.find_element(class: 'poll-option-add')

    poll_option_add.click
    poll_option_add.click
    poll_option_add.click
    poll_option_add.click

    inputs=poll_options.find_elements(css: 'input[type="text"]')
    inputs[0].send_keys('첫번째 선택 옵션')
    inputs[1].send_keys('두번째 선택 옵션')
    inputs[2].send_keys('세번째 선택 옵션')
    inputs[3].send_keys('네번째 선택 옵션')


    @driver.find_element(class: 'insert-poll').click

    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    reply_area = wait.until do
      element = @driver.find_element(class: 'reply-area')
      element if element.displayed? && element.enabled?
    end

    reply_area.find_element(class: 'create').click
  end
end
