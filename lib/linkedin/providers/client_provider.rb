# frozen_string_literal: true

require "oauth2"

module LinkedIn
  module Providers
    module ClientProvider
      TIMEOUT = 10

      class << self
        def auth(settings)
          linkedin = settings.linkedin

          Auth.new(client: oauth(settings), oauth_url: linkedin[:oauth_url], api_url: linkedin[:api_url])
        end

        def client(settings, http) = Client.new(auth: auth(settings), http:, api_url: settings.linkedin[:api_url])

        private

        def oauth(settings)
          linkedin = settings.linkedin
          credentials = linkedin.values_at(:client_id, :client_secret)
          return unless credentials.all?

          OAuth2::Client.new(
            *credentials,
            auth_scheme: :request_body, authorize_url: "#{linkedin[:oauth_url]}/authorization",
            token_url: "#{linkedin[:oauth_url]}/accessToken", connection_opts: { request: { timeout: TIMEOUT } },
          )
        end
      end
    end
  end
end
