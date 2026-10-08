# frozen_string_literal: true

module MCP
  module Actions
    module Metadata
      class ProtectedResource < Action
        include Deps["operations.describe_protected_resource"]

        def handle(_request, response)
          render_json(response, describe_protected_resource.call(issuer))
        end
      end
    end
  end
end
