# frozen_string_literal: true

module MCP
  module Operations
    class DescribeAuthorizationServer
      include Deps["routes"]

      def call(issuer)
        {
          authorization_endpoint: endpoint(:mcp_oauth_authorize),
          authorization_response_iss_parameter_supported: true,
          code_challenge_methods_supported: Blog::Types::CodeChallengeMethod.values,
          grant_types_supported: Blog::Types::OAuthGrantType.values,
          issuer:,
          registration_endpoint: endpoint(:mcp_oauth_register),
          response_types_supported: Blog::Types::OAuthResponseType.values,
          scopes_supported: Blog::Types::OAuthScope.values,
          token_endpoint: endpoint(:mcp_oauth_token),
          token_endpoint_auth_methods_supported: Blog::Types::OAuthTokenAuthMethod.values,
        }
      end

      private

      def endpoint(name) = routes.url(name).to_s
    end
  end
end
