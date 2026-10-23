# frozen_string_literal: true

module Google
  class Auth
    CHALLENGE_METHOD = "S256"
    PROMPT = "select_account"
    SCOPE = "openid email"

    def initialize(client:, userinfo_url:)
      @client = client
      @userinfo_url = userinfo_url
    end

    def configured? = !client.nil?

    def sign_in_url(redirect_uri:, state:, code_challenge:)
      client.auth_code.authorize_url(
        code_challenge:, code_challenge_method: CHALLENGE_METHOD, prompt: PROMPT, redirect_uri:, scope: SCOPE, state:,
      )
    end

    def verified_email(code:, redirect_uri:, code_verifier:)
      info = client.auth_code.get_token(code, redirect_uri:, code_verifier:).get(userinfo_url).parsed
      raise Error, "Google answered the user with no JSON profile" unless info.is_a?(Hash)

      info.fetch("email") if info["email_verified"] == true
    rescue *Blog::ServiceError::OAUTH_FAILURES => e
      raise Error, e.message
    end

    private

    attr_reader :client, :userinfo_url
  end
end
