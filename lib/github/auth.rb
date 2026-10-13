# frozen_string_literal: true

require "base64"
require "json"
require "multi_xml"

module GitHub
  class Auth
    ACCEPT = { "Accept" => "application/vnd.github+json" }.freeze
    CHALLENGE_METHOD = "S256"
    EMAILS_URL = "https://api.github.com/user/emails"
    SIGN_IN_SCOPE = "user:email"
    TOKEN_URL = "https://api.github.com/applications/%<client_id>s/token"
    USER_URL = "https://api.github.com/user"

    def initialize(client:)
      @client = client
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
      user = profile(token.get(USER_URL, headers: ACCEPT.dup))

      { access_token: token.token, account_id: user.fetch("id").to_s, label: "@#{user.fetch('login')}",
        scopes: token.params["scope"].to_s.split(",").map(&:strip).reject(&:empty?) }
    end

    def revoke(access_token)
      client.request(
        :delete, format(TOKEN_URL, client_id: client.id),
        body: JSON.generate(access_token:),
        headers: ACCEPT.merge("Authorization" => basic_auth, "Content-Type" => "application/json"),
      )
    end

    def sign_in_url(redirect_uri:, state:)
      client.auth_code.authorize_url(allow_signup: "false", redirect_uri:, scope: SIGN_IN_SCOPE, state:)
    end

    def verified_email(code:, redirect_uri:)
      emails = parse(exchange(code:, redirect_uri:).get(EMAILS_URL, headers: ACCEPT.dup))
      raise KeyError, "GitHub answered the emails with no JSON list" unless emails.is_a?(Array)

      emails.find { it.is_a?(Hash) && it["primary"] == true && it["verified"] == true }&.fetch("email")
    end

    private

    attr_reader :client

    def basic_auth = "Basic #{Base64.strict_encode64("#{client.id}:#{client.secret}")}"

    def exchange(code:, redirect_uri:, **)
      client.auth_code.get_token(code, redirect_uri:, **)
    rescue JSON::ParserError, MultiXML::ParseError
      raise KeyError, "GitHub answered the token with a body no parser reads"
    end

    def parse(response)
      response.parsed
    rescue JSON::ParserError, MultiXML::ParseError
      nil
    end

    def profile(response)
      body = parse(response)
      raise KeyError, "GitHub answered the user with no JSON profile" unless body.is_a?(Hash)

      body
    end
  end
end
