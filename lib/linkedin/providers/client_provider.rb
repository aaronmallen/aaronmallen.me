# frozen_string_literal: true

require "oauth2"

module LinkedIn
  module Providers
    module ClientProvider
      AUTHORIZE_URL = "https://www.linkedin.com/oauth/v2/authorization"
      TIMEOUT = 10
      TOKEN_URL = "https://www.linkedin.com/oauth/v2/accessToken"

      class << self
        def auth(settings) = Auth.new(client: oauth(settings))

        def client(settings) = Client.new(auth: auth(settings))

        private

        def oauth(settings)
          credentials = settings.linkedin.values_at(:client_id, :client_secret)
          return unless credentials.all?

          OAuth2::Client.new(
            *credentials,
            auth_scheme: :request_body, authorize_url: AUTHORIZE_URL, token_url: TOKEN_URL,
            connection_opts: { request: { timeout: TIMEOUT } },
          )
        end
      end
    end
  end
end
