# frozen_string_literal: true

module MCP
  module OAuth
    module Metadata
      BEARER_METHODS = %w[header].freeze
      CHALLENGE_METHODS = %w[S256].freeze
      GRANT_TYPES = %w[authorization_code refresh_token].freeze
      NO_TOKEN_AUTH = "none"
      RESPONSE_TYPES = %w[code].freeze
      TOKEN_AUTH_METHODS = [NO_TOKEN_AUTH].freeze

      class << self
        def authorization_server(issuer, routes)
          {
            authorization_endpoint: endpoint(routes, :mcp_oauth_authorize),
            authorization_response_iss_parameter_supported: true,
            code_challenge_methods_supported: CHALLENGE_METHODS,
            grant_types_supported: GRANT_TYPES,
            issuer:,
            registration_endpoint: endpoint(routes, :mcp_oauth_register),
            response_types_supported: RESPONSE_TYPES,
            scopes_supported: Scope::ALL,
            token_endpoint: endpoint(routes, :mcp_oauth_token),
            token_endpoint_auth_methods_supported: TOKEN_AUTH_METHODS,
          }
        end

        def protected_resource(issuer)
          {
            authorization_servers: [issuer],
            bearer_methods_supported: BEARER_METHODS,
            resource: at(issuer, Slice::RESOURCE_PATH),
            resource_name: Blog::Types::Normalized::Host.call(issuer),
          }
        end

        private

        def at(issuer, path) = "#{issuer}#{path}"

        def endpoint(routes, name) = routes.url(name).to_s
      end
    end
  end
end
