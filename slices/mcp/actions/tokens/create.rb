# frozen_string_literal: true

module MCP
  module Actions
    module Tokens
      class Create < Action
        include Deps[issue_token: "operations.issue_token"]

        def handle(request, response)
          response.cache_control(:no_store)

          case issue_token.call(request.params.to_h)
            in Success(tokens) then render_json(response, tokens)
            in Failure(Operations::IssueToken::REJECT, payload) then reject_json(response, payload)
            else reject_json(response)
          end
        end
      end
    end
  end
end
