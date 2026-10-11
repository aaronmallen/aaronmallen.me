# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Reopen < PageAction
        DONE = "decisions_page.toasts.reopened"
        OPEN = "decisions_page.toasts.open"

        include Deps[reopen_decision: "decisions.operations.reopen_decision"]

        def handle(request, response)
          params = decision_params(request)

          result = reopen_decision.call(record_id(request), params)

          case result
            in Failure(:open) then to_decision(request, response, OPEN)
            in Failure[:invalid, errors] then refuse_form(request, response, { name: :reopen, params:, errors: })
            else settle(response, result, DONE, decision_path(request))
          end
        end
      end
    end
  end
end
