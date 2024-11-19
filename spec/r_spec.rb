# frozen_string_literal: true

require 'selenium-webdriver'
require 'rspec'

RSpec.describe 'Google Search' do
  before(:each) do
    options = Selenium::WebDriver::Options.chrome
    @driver = Selenium::WebDriver.for :chrome, options: options
  end

  after(:each) do
    @driver.quit
  end

  it 'searches for Selenium Ruby' do
    @driver.navigate.to 'http://localhost:4200'
    search_box = @driver.find_element(name: 'q')
    search_box.send_keys('Selenium Ruby')
    search_box.submit

    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    wait.until { @driver.title.include?('Selenium Ruby') }

    expect(@driver.title).to include('Selenium Ruby')
  end
end
