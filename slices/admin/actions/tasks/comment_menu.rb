# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class CommentMenu < Action
        include Deps[task_queries: "tasks.repos.task_queries", view: "ui.views.comments.menu"]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:comment_id]] || halt(404)
          comment = task_queries.timeline(record_id(request)).find { it.comment? && it.source_id == id } || halt(404)

          response.render(view, comment:, owner: :task, owner_id: comment.task_id, return_to: back_here(request))
        end
      end
    end
  end
end
