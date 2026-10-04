# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UpdateComment < Action
        SAVED = "decisions_page.toasts.comment_saved"

        include PageForm
        include Deps[
          build_decision_page: "operations.build_decision_page",
          edit_decision_comment: "decisions.operations.edit_decision_comment",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:comment_id]] || halt(404)
          params = Blog::Types::Fields[request.params[:comment]]

          case edit_decision_comment.call(record_id(request), id, params)
          in Success(_) then to_decision(request, response, SAVED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then refuse_form(request, response, { name: :comment, id:, params:, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
