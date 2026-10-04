# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Reopen < Action
        DONE = "decisions_page.toasts.reopened"
        OPEN = "decisions_page.toasts.open"

        include PageForm
        include Deps[
          build_decision_page: "operations.build_decision_page",
          reopen_decision: "decisions.operations.reopen_decision",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          params = decision_params(request)

          case reopen_decision.call(record_id(request), params)
          in Success(_) then to_decision(request, response, DONE)
          in Failure(:open) then to_decision(request, response, OPEN)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then refuse_form(request, response, { name: :reopen, params:, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
