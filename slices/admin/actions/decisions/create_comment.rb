# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class CreateComment < Action
        ADDED = "decisions_page.toasts.comment_added"

        include PageForm
        include Deps[
          add_decision_comment: "decisions.operations.add_decision_comment",
          build_decision_page: "operations.build_decision_page",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:comment]]

          case add_decision_comment.call(record_id(request), params)
          in Success(_) then to_decision(request, response, ADDED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then refuse_form(request, response, { name: :comment, params:, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
