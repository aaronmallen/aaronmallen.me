# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class CreateComment < PageAction
        ADDED = "decisions_page.toasts.comment_added"

        include Deps[add_decision_comment: "decisions.operations.add_decision_comment"]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:comment]]

          result = add_decision_comment.call(record_id(request), params)

          settle(response, result, ADDED, decision_path(request)) do |errors|
            refuse_form(request, response, { name: :comment, params:, errors: })
          end
        end
      end
    end
  end
end
