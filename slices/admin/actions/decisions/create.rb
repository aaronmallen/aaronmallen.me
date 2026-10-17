# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Create < Action
        OPENED = "decisions_page.toasts.opened"

        include PageForm
        include Deps[
          build_decision_editor: "operations.build_decision_editor",
          open_decision: "decisions.operations.open_decision",
        ]

        def handle(request, response)
          params = decision_params(request)

          case open_decision.call(params)
            in Success(decision)
              toast(response, OPENED)
              response.redirect_to(routes.path(:admin_decision, id: decision.id))
            in Failure[:invalid, errors]
              unprocessable(response, view, **build_decision_editor.call(params:, errors:))
            else halt :internal_server_error
          end
        end
      end
    end
  end
end
