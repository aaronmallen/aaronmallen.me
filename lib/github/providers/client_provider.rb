# frozen_string_literal: true

require "oauth2"

module GitHub
  module Providers
    module ClientProvider
      HEADERS = {
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
      }.freeze
      PROVIDER = Blog::Types::ServiceProvider["github"]
      SIGN_IN_TIMEOUT = 10

      class << self
        def auth(settings)
          github = settings.github
          client = credentials(settings)&.then { sign_in(it, github[:oauth_url]) }

          Auth.new(client:, api_url: github[:api_url])
        end

        def client(settings, http)
          url = settings.github[:api_url]
          connect = ->(current) { { api: api(http, url, current), graphql: graphql(http, url, current) } }

          Client.new(transport: Transport.new(token: method(:token), connect:))
        end

        private

        def api(http, url, token)
          http.call(url:, headers: HEADERS.merge("Authorization" => "Bearer #{token}")) do |faraday|
            faraday.response :json
          end
        end

        def credentials(settings)
          found = settings.github.values_at(:client_id, :client_secret)

          found if found.all?
        end

        def graphql(http, url, token)
          http.call(url:, headers: { "Authorization" => "bearer #{token}" }) do |faraday|
            faraday.request :json
            faraday.response :json
          end
        end

        def services = Hanami.app.slices[:services]

        def sign_in(credentials, oauth_url)
          OAuth2::Client.new(
            *credentials,
            auth_scheme: :request_body,
            authorize_url: "#{oauth_url}/login/oauth/authorize",
            connection_opts: { request: { timeout: SIGN_IN_TIMEOUT } },
            token_url: "#{oauth_url}/login/oauth/access_token",
          )
        end

        def token = services["repos.connection_queries"].for(PROVIDER).first&.credentials&.fetch(:access_token, nil)
      end
    end
  end
end
