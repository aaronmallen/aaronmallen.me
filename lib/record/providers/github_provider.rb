# frozen_string_literal: true

module Record
  module Providers
    module GitHubProvider
      API_URL = "https://api.github.com"
      HEADERS = {
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
      }.freeze
      PROVIDER = Blog::Types::ServiceProvider["github"]

      class << self
        def client(connection_queries, http)
          token = -> { connection_queries.for(PROVIDER).first&.credentials&.fetch(:access_token, nil) }
          connect = ->(current) { { api: api(http, current), graphql: graphql(http, current) } }

          GitHub::Client.new(transport: GitHub::Transport.new(token:, connect:))
        end

        private

        def api(http, token)
          http.call(url: API_URL, headers: HEADERS.merge("Authorization" => "Bearer #{token}")) do |faraday|
            faraday.response :json
          end
        end

        def graphql(http, token)
          http.call(url: API_URL, headers: { "Authorization" => "bearer #{token}" }) do |faraday|
            faraday.request :json
            faraday.response :json
          end
        end
      end
    end
  end
end
