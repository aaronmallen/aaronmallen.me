# frozen_string_literal: true

require "capybara/rspec"
require "rack/test"

module Spec
  module Requests
    def api_token(scopes = nil)
      (@api_tokens ||= {})[scopes] ||=
        ::API::Slice["operations.mint_token"].call({ name: "Terminal", scopes: }.compact).value!.fetch(:value)
    end

    def call_api(verb, path, body = nil, token: api_token)
      headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
      headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
      body = JSON.generate(body) if verb.to_sym != :get && (body.is_a?(Hash) || body.is_a?(Array))
      public_send(verb, "/api/v1#{path}", body, headers)
      JSON.parse(last_response.body) if last_response.media_type == "application/json"
    end

    def document = JSON.parse(last_response.body)

    def menu_items = page.all(".ctx-label", visible: :all).map { it.text(:all) }

    def page = Capybara.string(last_response.body)

    def status = last_response.status

    def toast
      follow_redirect! if last_response.redirect?
      page.find("[data-toast] .toast", visible: :all).text(:all).strip
    end
  end
end

RSpec.configure do |config|
  config.include Rack::Test::Methods, type: :request
  config.include Capybara::RSpecMatchers, type: :request
  config.include Spec::Requests, type: :request
end
