# frozen_string_literal: true

module MCP
  module Actions
    module Metadata
      class AuthorizationServer < Action
        def handle(_request, response)
          render_json(response, OAuth::Metadata.authorization_server(issuer, routes))
        end
      end
    end
  end
end
