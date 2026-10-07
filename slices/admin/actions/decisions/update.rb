# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Update < Action
        SAVED = "decisions_page.toasts.saved"

        include PageForm
        include Deps[
          build_decision_editor: "operations.build_decision_editor",
          decision_queries: "decisions.repos.decision_queries",
          edit_decision: "decisions.operations.edit_decision",
        ]

        def handle(request, response)
          params = decision_params(request)

          result = edit_decision.call(record_id(request), params)

          case result
            in Failure[:invalid, errors] then invalid(request, response, params, errors)
            else settle(response, result, SAVED, decision_path(request))
          end
        end

        private

        def invalid(request, response, params, errors)
          decision = decision_queries.by_id(record_id(request))
          halt 404 unless decision

          response.status = 422
          response.render(view, **build_decision_editor.call(decision:, params:, errors:))
        end
      end
    end
  end
end
