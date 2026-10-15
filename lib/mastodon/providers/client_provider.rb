# frozen_string_literal: true

module Mastodon
  module Providers
    module ClientProvider
      HEADERS = { "Accept" => "application/json" }.freeze

      class << self
        def auth(settings) = Auth.new(website: settings.site_url)

        def client(http)
          connect = lambda do |host, token|
            headers = HEADERS.merge("Authorization" => "Bearer #{token}")
            http.call(url: "https://#{host}", headers:, redirects: 0) do |faraday|
              faraday.request :json
              faraday.response :json
            end
          end

          Client.new(connect:)
        end
      end
    end
  end
end
