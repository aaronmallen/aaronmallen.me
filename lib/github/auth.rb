# frozen_string_literal: true

require "base64"
require "json"

module GitHub
  class Auth
    ACCEPT = { "Accept" => "application/vnd.github+json" }.freeze
    CHALLENGE_METHOD = "S256"
    EMAILS_PATH = "/user/emails"
    SIGN_IN_SCOPE = "user:email"
    TOKEN_PATH = "/applications/%<client_id>s/token"
    USER_PATH = "/user"

    def initialize(client:, api_url:)
      @client = client
      @api_url = api_url
    end

    def configured? = !client.nil?

    def connect_url(redirect_uri:, state:, scope:, code_challenge:)
      client.auth_code.authorize_url(
        allow_signup: "false", code_challenge:, code_challenge_method: CHALLENGE_METHOD, redirect_uri:, scope:,
        state:,
      )
    end

    def grant(code:, redirect_uri:, code_verifier:)
      token = exchange(code:, redirect_uri:, code_verifier:)
      user = profile(token)

      { access_token: token.token, account_id: user.fetch("id").to_s, label: "@#{user.fetch('login')}",
        scopes: token.params["scope"].to_s.split(",").map(&:strip).reject(&:empty?) }
    rescue *Blog::ServiceError::OAUTH_FAILURES => e
      raise Error, e.message
    end

    def revoke(access_token)
      client.request(
        :delete, api(format(TOKEN_PATH, client_id: client.id)),
        body: JSON.generate(access_token:),
        headers: ACCEPT.merge("Authorization" => basic_auth, "Content-Type" => "application/json"),
      )
    end

    def sign_in_url(redirect_uri:, state:, code_challenge:)
      connect_url(redirect_uri:, state:, scope: SIGN_IN_SCOPE, code_challenge:)
    end

    def verified_email(code:, redirect_uri:, code_verifier:)
      emails = exchange(code:, redirect_uri:, code_verifier:).get(api(EMAILS_PATH), headers: ACCEPT.dup).parsed
      raise Error, "GitHub answered the emails with no JSON list" unless emails.is_a?(Array)

      emails.find { it.is_a?(Hash) && it["primary"] == true && it["verified"] == true }&.fetch("email")
    rescue *Blog::ServiceError::OAUTH_FAILURES => e
      raise Error, e.message
    end

    private

    attr_reader :api_url, :client

    def api(path) = "#{api_url}#{path}"

    def basic_auth = "Basic #{Base64.strict_encode64("#{client.id}:#{client.secret}")}"

    def exchange(code:, redirect_uri:, code_verifier:) = client.auth_code.get_token(code, redirect_uri:, code_verifier:)

    def profile(token)
      body = token.get(api(USER_PATH), headers: ACCEPT.dup).parsed
      raise Error, "GitHub answered the user with no JSON profile" unless body.is_a?(Hash)

      body
    end
  end
end
