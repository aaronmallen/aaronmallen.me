# frozen_string_literal: true

require "oauth2"

module GitHub
  module Providers
    module ClientProvider
      API_URL = "https://api.github.com"
      AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
      HEADERS = {
        "Accept" => "application/vnd.github+json",
        "X-GitHub-Api-Version" => "2022-11-28",
      }.freeze
      PROVIDER = Blog::Types::ServiceProvider["github"]
      SIGN_IN_TIMEOUT = 10
      TOKEN_URL = "https://github.com/login/oauth/access_token"

      class << self
        def auth(settings) = Auth.new(client: credentials(settings).then { it && sign_in(it) })

        def client(http)
          connect = ->(current) { { api: api(http, current), graphql: graphql(http, current) } }

          Client.new(transport: Transport.new(token: method(:token), connect:))
        end

        private

        def api(http, token)
          http.call(url: API_URL, headers: HEADERS.merge("Authorization" => "Bearer #{token}")) do |faraday|
            faraday.response :json
          end
        end

        def credentials(settings)
          found = settings.github.values_at(:client_id, :client_secret)

          found if found.all?
        end

        def graphql(http, token)
          http.call(url: API_URL, headers: { "Authorization" => "bearer #{token}" }) do |faraday|
            faraday.request :json
            faraday.response :json
          end
        end

        def services = Hanami.app.slices[:services]

        def sign_in(credentials)
          OAuth2::Client.new(
            *credentials,
            auth_scheme: :request_body,
            authorize_url: AUTHORIZE_URL,
            connection_opts: { request: { timeout: SIGN_IN_TIMEOUT } },
            token_url: TOKEN_URL,
          )
        end

        def token = services["repos.connection_queries"].for(PROVIDER).first&.credentials&.fetch(:access_token, nil)
      end
    end
  end
end
