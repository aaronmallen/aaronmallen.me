# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Resolve < Action
        CLOSED = "decisions_page.toasts.closed"
        DONE = "decisions_page.toasts.resolved"

        include PageForm
        include Deps[
          decision_by_id: "decisions.queries.by_id",
          resolve_decision: "decisions.operations.resolve_decision",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          params = decision_params(request)

          case resolve_decision.call(record_id(request), params)
          in Success(_) then to_decision(request, response, DONE)
          in Failure(:closed) then to_decision(request, response, CLOSED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then refuse_form(request, response, { name: :resolve, params:, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
