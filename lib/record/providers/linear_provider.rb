# frozen_string_literal: true

module Record
  module Providers
    module LinearProvider
      API_URL = "https://api.linear.app"

      class << self
        def client(connections, http)
          Linear::Client.new(connections:, transport: ->(key) { Linear::Transport.new(connection: graphql(http, key)) })
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
