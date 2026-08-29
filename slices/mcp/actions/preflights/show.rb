# frozen_string_literal: true

module MCP
  module Actions
    module Preflights
      class Show < Action
        ALLOWED_HEADERS = "Authorization, Content-Type, MCP-Protocol-Version"
        ALLOWED_METHODS = "POST"
        CORS_PREFIX = "access-control-"
        NO_CONTENT = 204

        def handle(_request, response)
          response.status = NO_CONTENT
          allow_any_origin(response)
          response.headers["Access-Control-Allow-Methods"] = ALLOWED_METHODS
          response.headers["Access-Control-Allow-Headers"] = ALLOWED_HEADERS
        end

        private

        def keep_response_header?(header) = super || header.downcase.start_with?(CORS_PREFIX)
      end
    end
  end
end
