# frozen_string_literal: true

require "oauth2"

module Health
  module Google
    class Client
      ACCOUNT = { account_id: "me", label: "Google account" }.freeze
      API_URL = "https://health.googleapis.com/v4/"
      CHALLENGE_METHOD = "S256"
      CHECK_PATH = "users/me/dataTypes/steps/dataPoints"
      INVALID_GRANT = "invalid_grant"
      LATENCY = 60
      NOT_CONNECTED = "Google Health isn't connected"
      NOT_SET_UP = "Google Health sign-in isn't set up"
      PROVIDER = Blog::Types::ServiceProvider["google_health"]
      RECONNECT = "Google Health needs a reconnect"
      REVOKE_URL = "https://oauth2.googleapis.com/revoke"
      UNAUTHORIZED = 401

      def initialize(oauth:, connection_queries:, change_connection:)
        @oauth = oauth
        @connection_queries = connection_queries
        @change_connection = change_connection
      end

      def account(**)
        raise Error, NOT_SET_UP unless configured?

        get(CHECK_PATH, page_size: 1)
        ACCOUNT
      end

      def configured? = !oauth.nil?

      def connect_url(redirect_uri:, scope:, state:, code_challenge:)
        oauth.auth_code.authorize_url(
          access_type: "offline", code_challenge:, code_challenge_method: CHALLENGE_METHOD, prompt: "consent",
          redirect_uri:, scope:, state:,
        )
      end

      def get(path, **params)
        return unless configured?

        connection = current
        token = token(connection.credentials)
        token = renew(connection, token) if token.expired?
        fetch(connection, token, path, params)
      end

      def grant(code:, redirect_uri:, code_verifier:)
        token = oauth.auth_code.get_token(code, redirect_uri:, code_verifier:)

        { **ACCOUNT, credentials: stored(token), scopes: token.params["scope"].to_s.split }
      end

      def revoke(credentials)
        oauth.request(:post, REVOKE_URL, body: { token: credentials[:refresh_token] || credentials[:access_token] })
      end

      private

      attr_reader :oauth

      def current
        connection = @connection_queries.for(PROVIDER).first
        raise Error, NOT_CONNECTED if connection.nil?
        raise Error, RECONNECT if connection.revoked_at

        connection
      end

      def fetch(connection, token, path, params, renewed: false)
        token.get(URI.join(API_URL, path).to_s, params:).parsed
      rescue OAuth2::Error => e
        raise Error, refusal(e) if renewed || e.response&.status != UNAUTHORIZED

        fetch(connection, renew(connection, token), path, params, renewed: true)
      rescue Faraday::Error => e
        raise Error, e.message
      end

      def refusal(error) = "Google answered #{error.response&.status || error.code}"

      def renew(connection, token)
        token.refresh.tap { @change_connection.call(connection.id, credentials: stored(it)) }
      rescue OAuth2::Error => e
        raise Error, refusal(e) unless e.code == INVALID_GRANT

        @change_connection.call(connection.id, revoked_at: Time.now)
        raise Error, RECONNECT
      rescue Faraday::Error => e
        raise Error, e.message
      end

      def stored(token)
        { access_token: token.token, expires_at: token.expires_at, refresh_token: token.refresh_token }
      end

      def token(credentials)
        OAuth2::AccessToken.new(
          oauth, credentials.fetch(:access_token),
          expires_at: credentials[:expires_at], expires_latency: LATENCY, refresh_token: credentials[:refresh_token],
        )
      end
    end
  end
end
