# frozen_string_literal: true

module Admin
  module Auth
    class Google
      PROMPT = "select_account"
      SCOPE = "openid email"
      USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"

      def initialize(client:)
        @client = client
      end

      def configured? = !client.nil?

      def sign_in_url(redirect_uri:, state:)
        client.auth_code.authorize_url(prompt: PROMPT, redirect_uri:, scope: SCOPE, state:)
      end

      def verified_email(code:, redirect_uri:)
        info = client.auth_code.get_token(code, redirect_uri:).get(USERINFO_URL).parsed
        raise KeyError, "Google answered the user with no JSON profile" unless info.is_a?(Hash)

        info.fetch("email") if info["email_verified"] == true
      end

      private

      attr_reader :client
    end
  end
end
