# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class CreateOption < Action
        ADDED = "decisions_page.toasts.option_added"
        CLOSED = "decisions_page.toasts.closed"

        include PageForm
        include Deps[
          add_decision_option: "decisions.operations.add_decision_option",
          build_decision_page: "operations.build_decision_page",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:option]]

          result = add_decision_option.call(record_id(request), params)

          case result
          in Failure(:closed) then to_decision(request, response, CLOSED)
          in Failure[:invalid, errors] then refuse_form(request, response, { name: :add_option, params:, errors: })
          else settle(response, result, ADDED, decision_path(request))
          end
        end
      end
    end
  end
end
