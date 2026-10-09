# frozen_string_literal: true

require "base64"
require "json"
require "multi_xml"

module Admin
  module Auth
    class GitHub
      ACCEPT = { "Accept" => "application/vnd.github+json" }.freeze
      CHALLENGE_METHOD = "S256"
      TOKEN_URL = "https://api.github.com/applications/%<client_id>s/token"
      USER_URL = "https://api.github.com/user"

      def initialize(client:)
        @client = client
      end

      def authorize_url(redirect_uri:, state:)
        client.auth_code.authorize_url(allow_signup: "false", redirect_uri:, state:)
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

      def user_id(code:, redirect_uri:)
        token = exchange(code:, redirect_uri:)
        profile(token.get(USER_URL, headers: ACCEPT.dup)).fetch("id")
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
end
