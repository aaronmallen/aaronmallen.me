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

    get "/sprints", to: "sprints.index"
    post "/sprints", to: "sprints.create"
    get "/sprints/current", to: "sprints.current"
    delete "/sprints/:id", to: "sprints.destroy"

    get "/token", to: "tokens.show"

    get "/openapi.json", to: "documents.show"
  end
end
