# frozen_string_literal: true

module Linear
  module Providers
    module ClientProvider
      class << self
        def client(settings, http)
          url = settings.linear[:api_url]

          Client.new(transport: ->(key) { Transport.new(connection: graphql(http, url, key)) })
        end

        private

        def graphql(http, url, key)
          http.call(url:, headers: { "Authorization" => key }) do |faraday|
            faraday.request :json
            faraday.response :json
          end
        end
      end
    end
  end
end
