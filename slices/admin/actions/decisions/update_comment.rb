# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UpdateComment < PageAction
        SAVED = "decisions_page.toasts.comment_saved"

        include Deps[edit_decision_comment: "decisions.operations.edit_decision_comment"]

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
