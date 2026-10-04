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

          case add_decision_option.call(record_id(request), params)
          in Success(_) then to_decision(request, response, ADDED)
          in Failure(:closed) then to_decision(request, response, CLOSED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then refuse_form(request, response, { name: :add_option, params:, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
