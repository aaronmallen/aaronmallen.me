# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class CommentMenu < Action
        include Deps[task_timeline_queries: "tasks.repos.task_timeline_queries", view: "ui.views.comments.menu"]

        def handle(request, response)
          id = record_id(request, :comment_id)
          comment = task_timeline_queries.entry(record_id(request), "comment", id) || halt(:not_found)

          response.render(view, comment:, owner: :task, owner_id: comment.task_id, return_to: back_here(request))
        end
      end
    end
  end
end
