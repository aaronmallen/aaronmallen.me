# frozen_string_literal: true

module Linear
  module Providers
    module ClientProvider
      API_URL = "https://api.linear.app"

      class << self
        def client(http) = Client.new(transport: ->(key) { Transport.new(connection: graphql(http, key)) })

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
