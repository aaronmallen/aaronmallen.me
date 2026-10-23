# frozen_string_literal: true

require "oauth2"

module Google
  module Providers
    module ClientProvider
      TIMEOUT = 10
      URLS = %i[calendar_url gmail_url health_url oauth_url openid_url people_url].freeze

      class << self
        def auth(settings) = Auth.new(client: oauth(settings), userinfo_url: "#{settings.google[:openid_url]}/userinfo")

        def client(settings) = Client.new(oauth: oauth(settings), urls: settings.google.slice(*URLS))

        def oauth(settings)
          google = settings.google
          credentials = google.values_at(:client_id, :client_secret)
          return unless credentials.all?

          OAuth2::Client.new(
            *credentials,
            auth_scheme: :request_body, authorize_url: "#{google[:accounts_url]}/o/oauth2/v2/auth",
            token_url: "#{google[:oauth_url]}/token", connection_opts: { request: { timeout: TIMEOUT } },
          )
        end
      end
    end
  end
end
