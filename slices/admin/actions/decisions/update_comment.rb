# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UpdateComment < PageAction
        SAVED = "decisions_page.toasts.comment_saved"

        include Deps[edit_decision_comment: "decisions.operations.edit_decision_comment"]

        def handle(request, response)
          id = record_id(request, :comment_id)
          params = Blog::Types::Fields[request.params[:comment]]

          result = edit_decision_comment.call(record_id(request), id, params)

          settle(response, result, SAVED, decision_path(request)) do |errors|
            refuse_form(request, response, { name: :comment, id:, params:, errors: })
          end
        end
      end
    end
  end
end
