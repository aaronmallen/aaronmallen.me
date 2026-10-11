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

          case result
            in Failure[:invalid, errors] then refuse_form(request, response, { name: :comment, params:, errors: })
            else settle(response, result, ADDED, decision_path(request))
          end
        end
      end
    end
  end
end
