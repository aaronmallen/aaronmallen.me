# frozen_string_literal: true

module MCP
  module Actions
    module Metadata
      class AuthorizationServer < Action
        include Deps["operations.describe_authorization_server"]

        def handle(_request, response)
          render_json(response, describe_authorization_server.call(issuer))
        end
      end
    end
  end
end
