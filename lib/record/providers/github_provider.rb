# frozen_string_literal: true

module Record
  module Providers
    module GitHubProvider
      API_URL = "https://api.github.com"
      HEADERS = {
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
      }.freeze

      class << self
        def client(settings, http)
          token = settings.github[:api_token]
          transport = GitHub::Transport.new(connection: token && api(http, token),
                                            graphql: token && graphql(http, token))

          GitHub::Client.new(transport:)
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
