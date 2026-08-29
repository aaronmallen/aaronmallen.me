# frozen_string_literal: true

module MCP
  module Actions
    module Metadata
      class ProtectedResource < Action
        def handle(_request, response)
          render_json(response, OAuth::Metadata.protected_resource(issuer))
        end
      end
    end
  end
end
