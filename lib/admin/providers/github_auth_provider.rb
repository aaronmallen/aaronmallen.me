# frozen_string_literal: true

require "oauth2"

module Admin
  module Providers
    module GitHubAuthProvider
      AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
      SIGN_IN_TIMEOUT = 10
      TOKEN_URL = "https://github.com/login/oauth/access_token"

      class << self
        def auth(settings) = Auth::GitHub.new(client: credentials(settings).then { it && sign_in(it) })

        private

        def credentials(settings)
          found = settings.github.values_at(:client_id, :client_secret)

          found if found.all?
        end

        def sign_in(credentials)
          OAuth2::Client.new(
            *credentials,
            auth_scheme: :request_body,
            authorize_url: AUTHORIZE_URL,
            connection_opts: { request: { timeout: SIGN_IN_TIMEOUT } },
            token_url: TOKEN_URL,
          )
        end
      end
    end
  end
end
