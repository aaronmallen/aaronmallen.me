# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class DestroyComment < Action
        DELETED = "decisions_page.toasts.comment_deleted"

        include PageForm
        include Deps[delete_decision_comment: "decisions.operations.delete_decision_comment"]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:comment_id]] || halt(404)

          case delete_decision_comment.call(record_id(request), id)
          in Success(_) then to_decision(request, response, DELETED)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end
      end
    end
  end
end
