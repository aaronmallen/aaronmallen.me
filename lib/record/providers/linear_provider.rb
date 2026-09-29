# frozen_string_literal: true

module Record
  module Providers
    module LinearProvider
      API_URL = "https://api.linear.app"

      class << self
        def client(settings, http)
          transports = settings.linear[:api_keys].map { Linear::Transport.new(connection: graphql(http, it)) }

          Linear::Client.new(transports:)
        end

        private

        def graphql(http, key)
          http.call(url: API_URL, headers: { "Authorization" => key }) do |faraday|
            faraday.request :json
            faraday.response :json
          end
        end
      end
    end
  end
end
