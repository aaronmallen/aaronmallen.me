# frozen_string_literal: true

require "oauth2"

module Google
  class Client
    CHALLENGE_METHOD = "S256"
    INVALID_GRANT = "invalid_grant"
    JSON_HEADERS = { "Content-Type" => "application/json" }.freeze
    LATENCY = 60
    NOT_FOUND = 404
    NOT_CONNECTED = "%s isn't connected"
    NOT_SET_UP = "Google sign-in isn't set up"
    PROMPT = "select_account consent"
    PROVIDER = Blog::Types::ServiceProvider["google"]
    RECONNECT = "%s needs a reconnect"
    REVOKE_URL = "https://oauth2.googleapis.com/revoke"
    UNAUTHORIZED = 401
    USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"

    def initialize(oauth:, connection_queries:, change_connection:)
      @oauth = oauth
      @connection_queries = connection_queries
      @change_connection = change_connection
    end

    def account(**credentials)
      raise Error, NOT_SET_UP unless configured?

      token = token(credentials)
      named(token.expired? ? token.refresh : token)
    rescue OAuth2::Error => e
      raise Error, refusal(e)
    rescue Faraday::Error => e
      raise Error, e.message
    end

    def configured? = !oauth.nil?

    def connect_url(redirect_uri:, scope:, state:, code_challenge:)
      oauth.auth_code.authorize_url(
        access_type: "offline", code_challenge:, code_challenge_method: CHALLENGE_METHOD, prompt: PROMPT,
        redirect_uri:, scope:, state:,
      )
    end

    def get(url, account:, **params) = request(account, :get, url, params:)

    def grant(code:, redirect_uri:, code_verifier:)
      token = oauth.auth_code.get_token(code, redirect_uri:, code_verifier:)

      { **named(token), credentials: stored(token), scopes: token.params["scope"].to_s.split }
    end

    def holders(scope)
      return [] unless configured?

      connections.select { |connection| connection.scopes.any? { it.start_with?(scope) } }.map(&:account_id)
    end

    def holding(scope) = holders(scope).first

    def post(url, body, account:) = request(account, :post, url, body: body.to_json, headers: JSON_HEADERS.dup)

    def revoke(credentials)
      oauth.request(:post, REVOKE_URL, body: { token: credentials[:refresh_token] || credentials[:access_token] })
    end

    private

    attr_reader :oauth

    def connection(account)
      connection = connections.find { it.account_id == account }
      raise Error, format(NOT_CONNECTED, account) if connection.nil?
      raise Error, format(RECONNECT, account) if connection.revoked_at

      connection
    end

    def connections = @connection_queries.for(PROVIDER)

    def fetch(connection, token, verb, url, options, renewed: false)
      token.request(verb, url.to_s, options).parsed
    rescue OAuth2::Error => e
      status = e.response&.status
      raise NotFound, refusal(e) if status == NOT_FOUND
      raise Error, refusal(e) if renewed || status != UNAUTHORIZED

      fetch(connection, renew(connection, token), verb, url, options, renewed: true)
    rescue Faraday::Error => e
      raise Error, e.message
    end

    def named(token)
      email = token.get(USERINFO_URL).parsed.fetch("email")

      { account_id: email, label: email }
    end

    def refusal(error) = "Google answered #{error.response&.status || error.code}"

    def renew(connection, token)
      token.refresh.tap { @change_connection.call(connection.id, credentials: stored(it)) }
    rescue OAuth2::Error => e
      raise Error, refusal(e) unless e.code == INVALID_GRANT

      @change_connection.call(connection.id, revoked_at: Time.now)
      raise Error, format(RECONNECT, connection.account_id)
    rescue Faraday::Error => e
      raise Error, e.message
    end

    def request(account, verb, url, **options)
      return unless configured?

      connection = connection(account)
      token = token(connection.credentials)
      token = renew(connection, token) if token.expired?
      fetch(connection, token, verb, url, options)
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
