# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Drop < Action
        CLOSED = "decisions_page.toasts.closed"
        DONE = "decisions_page.toasts.dropped"

        include PageForm
        include Deps[
          build_decision_page: "operations.build_decision_page",
          drop_decision: "decisions.operations.drop_decision",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          params = decision_params(request)

          result = drop_decision.call(record_id(request), params)

          case result
            in Failure(:closed) then to_decision(request, response, CLOSED)
            in Failure[:invalid, errors] then refuse_form(request, response, { name: :drop, params:, errors: })
            else settle(response, result, DONE, decision_path(request))
          end
        end
      end
    end
  end
end
