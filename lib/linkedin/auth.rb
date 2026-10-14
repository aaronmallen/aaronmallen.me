# frozen_string_literal: true

module LinkedIn
  class Auth
    REVOKE_URL = "https://www.linkedin.com/oauth/v2/revoke"
    SCOPES = /[\s,]+/
    USERINFO_URL = "https://api.linkedin.com/v2/userinfo"

    def initialize(client:)
      @client = client
    end

    def configured? = !client.nil?

    def connect_url(redirect_uri:, scope:, state:, **)
      client.auth_code.authorize_url(redirect_uri:, scope:, state:)
    end

    def grant(code:, redirect_uri:, **)
      token = client.auth_code.get_token(code, redirect_uri:)
      member = token.get(USERINFO_URL).parsed
      raise KeyError, "LinkedIn answered the member with no JSON profile" unless member.is_a?(Hash)

      { account_id: member.fetch("sub"), label: member.fetch("name"),
        credentials: { access_token: token.token, expires_at: token.expires_at },
        scopes: token.params["scope"].to_s.split(SCOPES) }
    end

    def revoke(access_token)
      body = { client_id: client.id, client_secret: client.secret, token: access_token }
      client.request(:post, REVOKE_URL, body:)
    end

    private

    attr_reader :client
  end
end
