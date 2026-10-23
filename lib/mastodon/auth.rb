# frozen_string_literal: true

require "oauth2"

module Mastodon
  class Auth
    APPS_PATH = "/api/v1/apps"
    AUTHORIZE_PATH = "/oauth/authorize"
    CHALLENGE_METHOD = "S256"
    REVOKE_PATH = "/oauth/revoke"
    TIMEOUT = 10
    TOKEN_PATH = "/oauth/token"
    VERIFY_PATH = "/api/v1/accounts/verify_credentials"

    def initialize(website:, instance_url:)
      @website = website
      @instance_url = instance_url
    end

    def connect_url(host, app, redirect_uri:, scope:, state:, code_challenge:)
      client(host, app).auth_code.authorize_url(
        code_challenge:, code_challenge_method: CHALLENGE_METHOD, redirect_uri:, scope:, state:,
      )
    end

    def grant(host, app, code:, redirect_uri:, code_verifier:)
      token = client(host, app).auth_code.get_token(code, redirect_uri:, code_verifier:)
      account = body(token.get(url(host, VERIFY_PATH)))

      { access_token: token.token, account_id: account.fetch("id").to_s,
        label: "@#{account.fetch('username')}@#{host}", scopes: token.params["scope"].to_s.split }
    rescue *Blog::ServiceError::OAUTH_FAILURES => e
      raise Error, e.message
    end

    def register(host, redirect_uri:, scope:)
      app = {
        client_name: Blog::Types::Normalized::Host.call(@website), redirect_uris: redirect_uri, scopes: scope,
        website: @website,
      }
      found = body(client(host).request(:post, url(host, APPS_PATH), body: app))

      { client_id: found.fetch("client_id"), client_secret: found.fetch("client_secret") }
    rescue *Blog::ServiceError::OAUTH_FAILURES => e
      raise Error, e.message
    end

    def revoke(host, app, token)
      client(host, app).request(:post, url(host, REVOKE_PATH),
                                body: { **app.slice(:client_id, :client_secret), token: })
    end

    private

    def body(response)
      parsed = response.parsed
      raise Error, "Mastodon answered with no JSON object" unless parsed.is_a?(Hash)

      parsed
    end

    def client(host, app = Blog::Constants::EMPTY_HASH)
      OAuth2::Client.new(
        app[:client_id], app[:client_secret],
        auth_scheme: :request_body, authorize_url: url(host, AUTHORIZE_PATH), site: url(host),
        token_url: url(host, TOKEN_PATH),
        connection_opts: { request: { timeout: TIMEOUT } }, max_redirects: 0,
      )
    end

    def url(host, path = nil) = "#{format(@instance_url, host:)}#{path}"
  end
end
