# frozen_string_literal: true

require "oauth2"

module Google
  class Client
    CHALLENGE_METHOD = "S256"
    FORBIDDEN = 403
    FULL_SCOPES = {
      "https://mail.google.com/" => "https://www.googleapis.com/auth/gmail.",
      "https://www.googleapis.com/auth/calendar" => "https://www.googleapis.com/auth/calendar.",
    }.freeze
    GONE = 410
    JSON_HEADERS = { "Content-Type" => "application/json" }.freeze
    NOT_FOUND = 404
    NOT_CONNECTED = "%s isn't connected"
    NOT_SET_UP = "Google sign-in isn't set up"
    PROMPT = "select_account consent"
    PROVIDER = Blog::Types::ServiceProvider["google"]
    RATE_LIMIT = /"(?:user)?rateLimitExceeded"/i
    RECONNECT = "%s needs a reconnect"
    REFUSALS = { NOT_FOUND => NotFound, GONE => Gone }.freeze
    REVOKE_URL = "https://oauth2.googleapis.com/revoke"
    TOO_MANY_REQUESTS = 429
    UNAUTHORIZED = 401
    USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"

    def initialize(oauth:, connections: nil, tokens: nil)
      @oauth = oauth
      @connections = connections
      @tokens = tokens || Tokens.new(oauth:, change_connection: method(:change_connection))
    end

    def account(**credentials)
      raise Error, NOT_SET_UP unless configured?

      @tokens.build(credentials).then { named(it.expired? ? it.refresh : it) }
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

    def delete(url, account:) = request(account, :delete, url)

    def get(url, account:, narrow: nil, **params) = request(account, :get, url, narrow:, params:)

    def grant(code:, redirect_uri:, code_verifier:)
      token = oauth.auth_code.get_token(code, redirect_uri:, code_verifier:)

      { **named(token), credentials: @tokens.stored(token), scopes: token.params["scope"].to_s.split }
    rescue *Blog::ServiceError::OAUTH_FAILURES => e
      raise Error, e.message
    end

    def holders(*scopes, lapsed: false)
      return [] unless configured?

      connections.reject { it.revoked_at unless lapsed }.filter_map do |connection|
        connection.account_id if scopes.all? { |scope| connection.scopes.any? { covers?(it, scope) } }
      end
    end

    def holding(scope) = holders(scope).first

    def loaded = self.class.new(oauth:, connections:, tokens: @tokens.remembering)

    def patch(url, body, account:) = request(account, :patch, url, body: body.to_json, headers: JSON_HEADERS.dup)

    def post(url, body, account:, narrow: nil)
      request(account, :post, url, narrow:, body: body.to_json, headers: JSON_HEADERS.dup)
    end

    def put(url, body, account:) = request(account, :put, url, body: body.to_json, headers: JSON_HEADERS.dup)

    def revoke(credentials)
      oauth.request(:post, REVOKE_URL, body: { token: credentials[:refresh_token] || credentials[:access_token] })
    end

    def work?(account) = connections.any? { it.account_id == account && it.work }

    private

    attr_reader :oauth

    def change_connection(...) = services["operations.change_connection"].call(...)

    def connection(account)
      connection = connections.find { it.account_id == account }
      raise Error, format(NOT_CONNECTED, account) if connection.nil?
      raise Error, format(RECONNECT, account) if connection.revoked_at

      connection
    end

    def connections = @connections || services["repos.connection_queries"].for(PROVIDER)

    def covers?(granted, wanted)
      granted.start_with?(wanted) || (FULL_SCOPES.key?(granted) && wanted.start_with?(FULL_SCOPES[granted]))
    end

    def fetch(connection, token, verb, url, options, narrow:, renewed: false)
      token.request(verb, url.to_s, options).parsed
    rescue OAuth2::Error => e
      raise refused(e.response), refusal(e) if renewed || e.response&.status != UNAUTHORIZED

      fresh = narrow ? narrowed(connection, narrow, fresh: true) : @tokens.renew(connection, token)
      fetch(connection, fresh, verb, url, options, narrow:, renewed: true)
    rescue Faraday::Error => e
      raise Error, e.message
    end

    def named(token)
      email = Hash.try_convert(token.get(USERINFO_URL).parsed).to_h.fetch("email")

      { account_id: email, label: email }
    end

    def narrowed(connection, prefix, fresh: false)
      @tokens.narrowed(connection, connection.scopes.select { covers?(it, prefix) }, fresh:)
    end

    def rate_limited?(response)
      response&.status == TOO_MANY_REQUESTS || (response&.status == FORBIDDEN && response.body.to_s.match?(RATE_LIMIT))
    end

    def refusal(error) = "Google answered #{error.response&.status || error.code}"

    def refused(response) = REFUSALS.fetch(response&.status) { rate_limited?(response) ? RateLimited : Error }

    def request(account, verb, url, narrow: nil, **options)
      return unless configured?

      connection = connection(account)
      token = narrow ? narrowed(connection, narrow) : @tokens.current(connection)
      fetch(connection, token, verb, url, options, narrow:)
    end

    def services = Hanami.app.slices[:services]
  end
end
