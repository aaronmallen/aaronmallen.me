# frozen_string_literal: true

module LinkedIn
  class Auth
    SCOPES = /[\s,]+/

    def initialize(client:, oauth_url:, api_url:)
      @client = client
      @oauth_url = oauth_url
      @api_url = api_url
    end

    def configured? = !client.nil?

    def connect_url(redirect_uri:, scope:, state:, **)
      client.auth_code.authorize_url(redirect_uri:, scope:, state:)
    end

    def grant(code:, redirect_uri:, **)
      token = client.auth_code.get_token(code, redirect_uri:)
      member = member(token)

      { account_id: member.fetch("sub"), label: member.fetch("name"),
        credentials: { access_token: token.token, expires_at: token.expires_at },
        scopes: token.params["scope"].to_s.split(SCOPES) }
    rescue *Blog::ServiceError::OAUTH_FAILURES => e
      raise Error, e.message
    end

    def revoke(access_token)
      body = { client_id: client.id, client_secret: client.secret, token: access_token }
      client.request(:post, "#{oauth_url}/revoke", body:)
    end

    private

    attr_reader :api_url, :client, :oauth_url

    def member(token)
      member = token.get("#{api_url}/v2/userinfo").parsed
      raise Error, "LinkedIn answered the member with no JSON profile" unless member.is_a?(Hash)

      member
    end
  end
end
