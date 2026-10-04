# frozen_string_literal: true

module API
  class Routes < Hanami::Routes
    get "/journal_entries", to: "journal_entries.index"
    post "/journal_entries", to: "journal_entries.create"
    get "/journal_entries/:id", to: "journal_entries.show"
    patch "/journal_entries/:id", to: "journal_entries.update"
    delete "/journal_entries/:id", to: "journal_entries.destroy"

    get "/tasks", to: "tasks.index"
    post "/tasks", to: "tasks.create"
    get "/tasks/:id", to: "tasks.show"
    patch "/tasks/:id", to: "tasks.update"
    delete "/tasks/:id", to: "tasks.destroy"
    post "/tasks/:id/cancel", to: "tasks.cancel"
    post "/tasks/:id/complete", to: "tasks.complete"
    post "/tasks/:id/move", to: "tasks.move"
    post "/tasks/:id/reopen", to: "tasks.reopen"
    post "/tasks/:id/reorder", to: "tasks.reorder"
    post "/tasks/:id/schedule", to: "tasks.schedule"
    post "/tasks/:id/start", to: "tasks.start"
    post "/tasks/:id/comments", to: "task_comments.create"
    post "/tasks/:id/links", to: "task_links.create"
    delete "/tasks/:id/links/:other_id", to: "task_links.destroy"

    post "/decisions", to: "decisions.create"
    patch "/decisions/:id", to: "decisions.update"
    post "/decisions/:id/drop", to: "decisions.drop"
    post "/decisions/:id/reopen", to: "decisions.reopen"
    post "/decisions/:id/resolve", to: "decisions.resolve"
    post "/decisions/:id/options", to: "decision_options.create"
    patch "/decisions/:id/options/:option_id", to: "decision_options.update"
    delete "/decisions/:id/options/:option_id", to: "decision_options.destroy"
    post "/decisions/:id/comments", to: "decision_comments.create"
    patch "/decisions/:id/comments/:comment_id", to: "decision_comments.update"
    delete "/decisions/:id/comments/:comment_id", to: "decision_comments.destroy"
    post "/decisions/:id/tags", to: "decision_tags.create"
    delete "/decisions/:id/tags/:tag", to: "decision_tags.destroy"

    get "/links/:kind/:id", to: "record_links.index"
    post "/links/:kind/:id", to: "record_links.create"
    delete "/links/:kind/:id/:other_kind/:other_id", to: "record_links.destroy"

    get "/review", to: "reviews.show"

    get "/sprints", to: "sprints.index"
    post "/sprints", to: "sprints.create"
    get "/sprints/current", to: "sprints.current"
    delete "/sprints/:id", to: "sprints.destroy"

    get "/saved_views", to: "saved_views.index"
    post "/saved_views", to: "saved_views.create"
    patch "/saved_views/:id", to: "saved_views.update"
    delete "/saved_views/:id", to: "saved_views.destroy"

    get "/token", to: "tokens.show"

    get "/openapi.json", to: "documents.show"
  end
end
