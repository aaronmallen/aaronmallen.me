# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Update < Action
        SAVED = "decisions_page.toasts.saved"

        include PageForm
        include Deps[
          build_decision_editor: "operations.build_decision_editor",
          decision_by_id: "decisions.queries.by_id",
          edit_decision: "decisions.operations.edit_decision",
        ]

        def handle(request, response)
          params = decision_params(request)

          case edit_decision.call(record_id(request), params)
          in Success(_) then to_decision(request, response, SAVED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(request, response, params, errors)
          else halt 500
          end
        end

        private

        def invalid(request, response, params, errors)
          decision = decision_by_id.call(record_id(request))
          halt 404 unless decision

          response.status = 422
          response.render(view, **build_decision_editor.call(decision:, params:, errors:))
        end
      end
    end
  end
end
