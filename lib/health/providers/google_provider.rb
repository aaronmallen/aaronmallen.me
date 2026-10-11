# frozen_string_literal: true

require "oauth2"

module Health
  module Providers
    module GoogleProvider
      AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
      TIMEOUT = 10
      TOKEN_URL = "https://oauth2.googleapis.com/token"

      class << self
        def client(settings, connection_queries, change_connection)
          Google::Client.new(oauth: oauth(settings), connection_queries:, change_connection:)
        end

        private

        def oauth(settings)
          credentials = settings.google_health.values_at(:client_id, :client_secret)
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
