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
    post "/tasks/bulk/cancel", to: "bulk_tasks.cancel"
    post "/tasks/bulk/complete", to: "bulk_tasks.complete"
    post "/tasks/bulk/delete", to: "bulk_tasks.delete"
    post "/tasks/bulk/move", to: "bulk_tasks.move"
    post "/tasks/bulk/tag", to: "bulk_tasks.tag"
    post "/tasks/bulk/untag", to: "bulk_tasks.untag"
    get "/tasks/:id", to: "tasks.show"
    patch "/tasks/:id", to: "tasks.update"
    delete "/tasks/:id", to: "tasks.destroy"
    post "/tasks/:id/cancel", to: "tasks.cancel"
    post "/tasks/:id/complete", to: "tasks.complete"
    post "/tasks/:id/move", to: "tasks.move"
    post "/tasks/:id/reopen", to: "tasks.reopen"
    post "/tasks/:id/reorder", to: "tasks.reorder"
    post "/tasks/:id/schedule", to: "tasks.schedule"
    post "/tasks/:id/pause", to: "tasks.pause"
    post "/tasks/:id/start", to: "tasks.start"
    post "/tasks/:id/total", to: "tasks.set_total"
    patch "/tasks/:id/sessions/:session_id", to: "task_sessions.update"
    delete "/tasks/:id/sessions/:session_id", to: "task_sessions.destroy"
    post "/tasks/:id/comments", to: "task_comments.create"
    post "/tasks/:id/links", to: "task_links.create"
    delete "/tasks/:id/links/:other_id", to: "task_links.destroy"

    get "/decisions", to: "decisions.index"
    post "/decisions", to: "decisions.create"
    get "/decisions/:id", to: "decisions.show"
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

    post "/messages/bulk/delete", to: "bulk_messages.delete"
    post "/messages/bulk/read", to: "bulk_messages.read"
    post "/messages/bulk/unread", to: "bulk_messages.unread"

    post "/posts/bulk/delete", to: "bulk_posts.delete"
    post "/posts/bulk/tag", to: "bulk_posts.tag"

    get "/attention", to: "attention.index"

    get "/inbox", to: "inbox.index"

    get "/links/:kind/:id", to: "record_links.index"
    post "/links/:kind/:id", to: "record_links.create"
    delete "/links/:kind/:id/:other_kind/:other_id", to: "record_links.destroy"

    get "/review", to: "reviews.show"

    get "/search", to: "search.index"

    get "/sprints", to: "sprints.index"
    post "/sprints", to: "sprints.create"
    get "/sprints/current", to: "sprints.current"
    delete "/sprints/:id", to: "sprints.destroy"

    get "/saved_views", to: "saved_views.index"
    post "/saved_views", to: "saved_views.create"
    patch "/saved_views/:id", to: "saved_views.update"
    delete "/saved_views/:id", to: "saved_views.destroy"

    get "/time_report", to: "time_reports.show"

    post "/webmentions/bulk/approve", to: "bulk_webmentions.approve"
    post "/webmentions/bulk/ignore", to: "bulk_webmentions.ignore"
    post "/webmentions/bulk/spam", to: "bulk_webmentions.spam"

    get "/token", to: "tokens.show"

    get "/openapi.json", to: "documents.show"
  end
end
