# frozen_string_literal: true

module Admin
  class Routes < Hanami::Routes
    DIRECTION = Regexp.union(Blog::Types::ProjectMove.values)
    ID = /\d+/
    MARKDOWN_RENDERER = Regexp.union(Blog::Types::MarkdownRenderer.values)
    MESSAGE_STATUS = Regexp.union(Blog::Types::MessageStatus.values)
    TASK_FILTER = Regexp.union(Blog::Types::TaskFilter.values)
    TASK_MOVE = Regexp.union(Blog::Types::TaskMove.values)

    use(*Admin::Slice.config.actions.sessions.middleware)

    get "/", to: "today.show", as: :root
    post "/", to: "today.create_journal_entry", as: :create_today_journal_entry
    get "/activity", to: "activity.show", as: :activity
    get "/analytics", to: "analytics.show", as: :analytics
    get "/clients", to: "clients.index", as: :clients
    post "/clients/:id/revoke", to: "clients.revoke", as: :revoke_client, id: ID
    get "/commits/:id", to: "commits.show", as: :commit, id: ID
    post "/commits/import", to: "commits.import", as: :import_commits
    get "/journal", to: "journal.index", as: :journal
    post "/journal", to: "journal.create", as: :create_journal_entry
    post "/journal/:id", to: "journal.update", as: :update_journal_entry, id: ID
    post "/journal/:id/delete", to: "journal.destroy", as: :delete_journal_entry, id: ID
    post "/markdown/preview/:renderer", to: "markdown.preview", as: :preview_markdown, renderer: MARKDOWN_RENDERER
    get "/messages", to: "messages.index", as: :messages
    post "/messages/:id/mark/:status", to: "messages.mark", as: :mark_message, id: ID, status: MESSAGE_STATUS
    get "/people", to: "people.index", as: :people
    post "/people", to: "people.create", as: :create_person
    get "/people/new", to: "people.new", as: :new_person
    get "/people/:id/edit", to: "people.edit", as: :edit_person, id: ID
    post "/people/:id", to: "people.update", as: :update_person, id: ID
    post "/people/:id/delete", to: "people.destroy", as: :delete_person, id: ID
    post "/photos", to: "photos.create", as: :create_photo
    get "/posts", to: "posts.index", as: :posts
    post "/posts", to: "posts.create", as: :create_post
    get "/posts/new", to: "posts.new", as: :new_post
    get "/posts/:id/edit", to: "posts.edit", as: :edit_post, id: ID
    post "/posts/:id", to: "posts.update", as: :update_post, id: ID
    post "/posts/:id/delete", to: "posts.destroy", as: :delete_post, id: ID
    post "/posts/preview", to: "posts.preview", as: :preview_post
    post "/posts/preview/syndication", to: "posts.preview_syndication", as: :preview_post_syndication
    post "/posts/:id/suggestions/accept", to: "posts.accept_suggestions", as: :accept_post_suggestions, id: ID
    post "/posts/:id/suggestions/reject", to: "posts.reject_suggestions", as: :reject_post_suggestions, id: ID
    get "/projects", to: "projects.index", as: :projects
    post "/projects", to: "projects.create", as: :create_project
    get "/projects/new", to: "projects.new", as: :new_project
    get "/projects/:id/edit", to: "projects.edit", as: :edit_project, id: ID
    post "/projects/:id", to: "projects.update", as: :update_project, id: ID
    post "/projects/:id/archive", to: "projects.archive", as: :archive_project, id: ID
    post "/projects/:id/move/:direction", to: "projects.move", as: :move_project, id: ID, direction: DIRECTION
    post "/projects/:id/restore", to: "projects.restore", as: :restore_project, id: ID
    post "/projects/work", to: "projects.create_work", as: :create_work_entry
    post "/projects/work/:id/delete", to: "projects.destroy_work", as: :delete_work_entry, id: ID
    get "/social", to: "social.index", as: :social
    post "/social", to: "social.create", as: :create_social_post
    post "/social/:id", to: "social.update", as: :update_social_post, id: ID
    post "/social/:id/delete", to: "social.destroy", as: :delete_social_post, id: ID
    post "/social/:id/suggestions/accept", to: "social.accept_suggestions", as: :accept_social_suggestions, id: ID
    post "/social/:id/suggestions/reject", to: "social.reject_suggestions", as: :reject_social_suggestions, id: ID
    get "/tags", to: "tags.index", as: :tags
    post "/tags", to: "tags.create", as: :create_tag
    post "/tags/:id", to: "tags.update", as: :update_tag, id: ID
    post "/tags/:id/delete", to: "tags.destroy", as: :delete_tag, id: ID
    get "/tasks", to: "tasks.index", as: :tasks
    post "/tasks", to: "tasks.create", as: :create_task
    get "/tasks/new", to: "tasks.new", as: :new_task
    get "/tasks/:id", to: "tasks.show", as: :task, id: ID
    get "/tasks/:id/edit", to: "tasks.edit", as: :edit_task, id: ID
    post "/tasks/:id", to: "tasks.update", as: :update_task, id: ID
    post "/tasks/:id/cancel", to: "tasks.cancel", as: :cancel_task, id: ID
    post "/tasks/:id/comments", to: "tasks.create_comment", as: :create_task_comment, id: ID
    post(
      "/tasks/:id/comments/:comment_id",
      to: "tasks.update_comment", as: :update_task_comment, id: ID, comment_id: ID,
    )
    post(
      "/tasks/:id/comments/:comment_id/delete",
      to: "tasks.destroy_comment", as: :delete_task_comment, id: ID, comment_id: ID,
    )
    post "/tasks/:id/complete", to: "tasks.complete", as: :complete_task, id: ID
    post "/tasks/:id/delete", to: "tasks.destroy", as: :delete_task, id: ID
    post "/tasks/:id/links", to: "tasks.link", as: :link_task, id: ID
    post "/tasks/:id/links/:other_id/delete", to: "tasks.unlink", as: :unlink_task, id: ID, other_id: ID
    post "/tasks/:id/move/:filter", to: "tasks.move", as: :move_task, id: ID, filter: TASK_FILTER
    post "/tasks/:id/reopen", to: "tasks.reopen", as: :reopen_task, id: ID
    post "/tasks/:id/reorder/:direction", to: "tasks.reorder", as: :reorder_task, id: ID, direction: TASK_MOVE
    post "/tasks/:id/schedule", to: "tasks.schedule", as: :schedule_task, id: ID
    post "/tasks/:id/start", to: "tasks.start", as: :start_task, id: ID
    post "/tasks/:id/stop", to: "tasks.stop", as: :stop_task, id: ID
    post "/tasks/issues/sync", to: "issues.sync", as: :sync_issues
    post "/tasks/sprints", to: "sprints.create", as: :plan_sprint
    post "/tasks/sprints/:id/delete", to: "sprints.destroy", as: :drop_sprint, id: ID
    get "/webmentions", to: "webmentions.index", as: :webmentions
    post "/webmentions/settings", to: "webmentions.update_settings", as: :update_webmention_settings
    post "/webmentions/:id/approve", to: "webmentions.approve", as: :approve_webmention, id: ID
    post "/webmentions/:id/spam", to: "webmentions.spam", as: :spam_webmention, id: ID
    post "/webmentions/:id/ignore", to: "webmentions.ignore", as: :ignore_webmention, id: ID
    get "/sign-in", to: "sessions.new", as: :sign_in
    get "/auth/github/callback", to: "sessions.create", as: :github_callback
    post "/sign-out", to: "sessions.destroy", as: :sign_out
    get "/*path", to: "not_found"
  end
end
