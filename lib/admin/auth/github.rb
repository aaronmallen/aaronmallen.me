# frozen_string_literal: true

require "json"
require "multi_xml"

module Admin
  module Auth
    class GitHub
      USER_URL = "https://api.github.com/user"

      def initialize(client:)
        @client = client
      end

      def authorize_url(redirect_uri:, state:)
        client.auth_code.authorize_url(allow_signup: "false", redirect_uri:, state:)
      end

      def configured? = !client.nil?

      def user_id(code:, redirect_uri:)
        token = exchange(code:, redirect_uri:)
        profile(token.get(USER_URL, headers: { "Accept" => "application/vnd.github+json" })).fetch("id")
      end

      private

      attr_reader :client

      def exchange(code:, redirect_uri:)
        client.auth_code.get_token(code, redirect_uri:)
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
