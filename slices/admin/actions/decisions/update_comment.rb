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

          result = edit_decision_comment.call(record_id(request), id, params)

          case result
          in Failure[:invalid, errors] then refuse_form(request, response, { name: :comment, id:, params:, errors: })
          else settle(response, result, SAVED, decision_path(request))
          end
        end
      end
    end
  end
end
