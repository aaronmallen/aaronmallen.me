# frozen_string_literal: true

require "oauth2"

module Google
  class Tokens
    INVALID_GRANT = "invalid_grant"
    LATENCY = 60

    def initialize(oauth:, change_connection:, current: nil)
      @oauth = oauth
      @change_connection = change_connection
      @current = current
      @narrowed = {}
    end

    def build(credentials)
      OAuth2::AccessToken.new(
        @oauth, credentials.fetch(:access_token),
        expires_at: credentials[:expires_at], expires_latency: LATENCY, refresh_token: credentials[:refresh_token],
      )
    end

    def current(connection)
      token = @current&.fetch(connection.id, nil) || build(connection.credentials)
      token.expired? ? renew(connection, token) : token
    end

    def narrowed(connection, scopes, fresh: false)
      refresh_token = connection.credentials[:refresh_token]
      token = @narrowed[[refresh_token, scopes]]
      return token if token && !fresh && !token.expired?

      @narrowed[[refresh_token, scopes]] = refreshed(connection) do
        params = { grant_type: "refresh_token", refresh_token:, scope: scopes.join(" ") }
        @oauth.get_token(params, expires_latency: LATENCY)
      end
    end

    def remembering = self.class.new(oauth: @oauth, change_connection: @change_connection, current: {})

    def renew(connection, token)
      refreshed(connection) { token.refresh }.tap do |fresh|
        @change_connection.call(connection.id, credentials: stored(fresh))
        @current[connection.id] = fresh if @current
      end
    end

    def stored(token) = { access_token: token.token, expires_at: token.expires_at, refresh_token: token.refresh_token }

    private

    def refreshed(connection)
      yield
    rescue OAuth2::Error => e
      raise Error, "Google answered #{e.response&.status || e.code}" unless e.code == INVALID_GRANT

      @change_connection.call(connection.id, revoked_at: Time.now)
      raise Error, format(Client::RECONNECT, connection.account_id)
    rescue Faraday::Error => e
      raise Error, e.message
    end
  end
end
