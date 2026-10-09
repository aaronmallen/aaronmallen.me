# frozen_string_literal: true

require "oauth2"

module Admin
  module Auth
    class Mastodon
      APPS_PATH = "/api/v1/apps"
      AUTHORIZE_PATH = "/oauth/authorize"
      CHALLENGE_METHOD = "S256"
      REVOKE_PATH = "/oauth/revoke"
      TIMEOUT = 10
      TOKEN_PATH = "/oauth/token"
      VERIFY_PATH = "/api/v1/accounts/verify_credentials"

      def initialize(website:)
        @website = website
      end

      def connect_url(host, app, redirect_uri:, scope:, state:, code_challenge:)
        client(host, app).auth_code.authorize_url(
          code_challenge:, code_challenge_method: CHALLENGE_METHOD, redirect_uri:, scope:, state:,
        )
      end

      def grant(host, app, code:, redirect_uri:, code_verifier:)
        token = client(host, app).auth_code.get_token(code, redirect_uri:, code_verifier:)
        account = body(token.get(VERIFY_PATH))

        { access_token: token.token, account_id: account.fetch("id").to_s,
          label: "@#{account.fetch('username')}@#{host}", scopes: token.params["scope"].to_s.split }
      end

      def register(host, redirect_uri:, scope:)
        app = { client_name: URI(@website).host, redirect_uris: redirect_uri, scopes: scope, website: @website }
        found = body(client(host).request(:post, APPS_PATH, body: app))

        { client_id: found.fetch("client_id"), client_secret: found.fetch("client_secret") }
      end

      def revoke(host, app, token)
        client(host, app).request(:post, REVOKE_PATH, body: { **app.slice(:client_id, :client_secret), token: })
      end

      private

      def body(response)
        parsed = response.parsed
        raise KeyError, "Mastodon answered with no JSON object" unless parsed.is_a?(Hash)

        parsed
      end

      def client(host, app = Blog::Constants::EMPTY_HASH)
        OAuth2::Client.new(
          app[:client_id], app[:client_secret],
          auth_scheme: :request_body, authorize_url: AUTHORIZE_PATH, site: "https://#{host}", token_url: TOKEN_PATH,
          connection_opts: { request: { timeout: TIMEOUT } },
        )
      end
    end
  end
end
