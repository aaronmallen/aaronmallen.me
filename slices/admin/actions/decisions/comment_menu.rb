# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class CommentMenu < Action
        include Deps[decision_queries: "decisions.repos.decision_queries", view: "ui.views.comments.menu"]

        def handle(request, response)
          id = record_id(request, :comment_id)
          decision_id = record_id(request)
          comment = decision_queries.timeline_entry(decision_id, "comment", id) || halt(404)

          response.render(view, comment:, owner: :decision, owner_id: decision_id, return_to: back_here(request))
        end
      end
    end
  end
end
