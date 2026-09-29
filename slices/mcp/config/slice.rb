# frozen_string_literal: true

require "mcp"

module MCP
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/mcp"), namespace: MCP)

    OAUTH_PREFIX = "/oauth"
    RESOURCE_PATH = "/mcp"

    config.no_auto_register_paths += %w[prompts tools]

    config.shared_app_component_keys += %w[assets honeybadger.agent]

    config.actions.content_security_policy[:frame_ancestors] = "'none'"
    config.actions.content_security_policy[:form_action] = "'self' https: http:"

    config.actions.csrf_protection = false

    config.actions.sessions = Blog::SessionCookie.store

    import keys: %w[auth.session_reader], from: :admin

    import keys: %w[
      queries.activity_between queries.activity_commit_totals queries.activity_counts
      queries.activity_counts_by_month
    ], from: :activity

    import keys: %w[operations.hash_visitor queries.summary_between], from: :analytics

    import keys: %w[operations.mark_message queries.by_id queries.received_between], from: :contact

    import keys: %w[
      operations.compose_announcement operations.delete_post operations.save_post operations.save_post_seo queries.by_id
      queries.dated_between
    ], from: :posts

    import keys: %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry operations.move_project
      operations.restore_project operations.save_project queries.archived queries.by_id queries.live
      queries.work_entries_between
    ], from: :projects

    import keys: %w[operations.find_visitor_address], from: :public

    import keys: %w[
      operations.delete_journal_entry operations.queue_commit_import operations.save_journal_entry
      operations.update_journal_entry queries.commits_between queries.commits_last_synced_at
      queries.journal_entries_between queries.journal_entry_by_id queries.sync_failures
    ], from: :record

    import keys: %w[
      operations.compose_social_post operations.delete_social_post operations.moderate_webmention
      operations.update_webmention_settings queries.editable_social_post queries.social_posts_dated_between
      queries.unsent_social_posts queries.webmention_settings queries.webmentions_received_in
    ], from: :social

    import keys: %w[
      operations.accept_suggestion_edits operations.reject_edits operations.replace_post_edits
      operations.replace_social_post_edits queries.by_id queries.created_between
    ], from: :suggestions

    import keys: %w[operations.remove_tag operations.save_tag queries.all queries.matching queries.usage], from: :tags

    import keys: %w[
      operations.add_task_comment operations.cancel_task operations.capture_task operations.complete_task
      operations.current_sprint operations.delete_task operations.drop_sprint operations.link_tasks operations.move_task
      operations.plan_sprint operations.reopen_task operations.reorder_task operations.save_task
      operations.schedule_task operations.start_task operations.unlink_task queries.find_tasks queries.sprints_between
      queries.task_by_id queries.task_comments queries.tasks_in_sprint
    ], from: :tasks

    export %w[operations.revoke_client queries.connected_clients]
  end
end
