# frozen_string_literal: true

require "capybara/rspec"
require "rack/test"

RSpec.configure do |config|
  config.include Rack::Test::Methods, type: :request
  config.include Capybara::RSpecMatchers, type: :request
end
