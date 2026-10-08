# frozen_string_literal: true

module MCP
  module Operations
    class DescribeProtectedResource
      BEARER_METHODS = %w[header].freeze

      def call(issuer)
        {
          authorization_servers: [issuer],
          bearer_methods_supported: BEARER_METHODS,
          resource: "#{issuer}#{Slice::RESOURCE_PATH}",
          resource_name: Blog::Types::Normalized::Host.call(issuer),
          scopes_supported: Blog::Types::OAuthScope.values,
        }
      end
    end
  end
end
