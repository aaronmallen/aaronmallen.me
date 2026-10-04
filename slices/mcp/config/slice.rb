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
      endpoints.add_decision_comment endpoints.add_decision_option endpoints.add_task_comment endpoints.cancel_task
      endpoints.cancel_tasks endpoints.capture_task endpoints.complete_task endpoints.complete_tasks
      endpoints.create_journal_entry endpoints.create_saved_view endpoints.delete_decision_comment
      endpoints.delete_decision_option endpoints.delete_journal_entry endpoints.delete_saved_view endpoints.delete_task
      endpoints.delete_tasks endpoints.delete_work_session endpoints.drop_decision endpoints.drop_sprint
      endpoints.edit_decision endpoints.edit_decision_comment endpoints.edit_decision_option endpoints.link_records
      endpoints.link_tasks endpoints.list_attention endpoints.list_journal_entries endpoints.list_links
      endpoints.list_saved_views endpoints.list_sprints endpoints.list_tasks endpoints.move_task endpoints.move_tasks
      endpoints.open_decision endpoints.pause_task endpoints.plan_sprint endpoints.read_current_sprint
      endpoints.read_journal_entry endpoints.read_review endpoints.read_task endpoints.read_time_report
      endpoints.reopen_decision endpoints.reopen_task endpoints.reorder_task endpoints.resolve_decision
      endpoints.save_task endpoints.schedule_task endpoints.search endpoints.set_task_total endpoints.start_task
      endpoints.tag_decision endpoints.tag_tasks endpoints.unlink_records endpoints.unlink_task endpoints.untag_decision
      endpoints.untag_tasks endpoints.update_journal_entry endpoints.update_saved_view endpoints.update_work_session
    ], from: :api

    import keys: %w[
      queries.activity_between queries.activity_commit_totals queries.activity_counts
      queries.activity_counts_by_month
    ], from: :activity

    import keys: %w[
      operations.hash_visitor queries.devices_between queries.hourly_between queries.navigation_between
      queries.page_between queries.reach_between queries.read_spread_between queries.scroll_depths_between
      queries.sources_between queries.summary_between
    ], from: :analytics

    import keys: %w[operations.mark_message queries.by_id queries.received_between], from: :contact

    import keys: %w[
      operations.compose_announcement operations.delete_post operations.save_post operations.save_post_seo queries.by_id
      queries.dated_between queries.published_by_slug
    ], from: :posts

    import keys: %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry operations.move_project
      operations.restore_project operations.save_project queries.archived queries.by_id queries.live
      queries.work_entries_between
    ], from: :projects

    import keys: %w[operations.find_visitor_address], from: :public

    import keys: %w[
      operations.queue_commit_import queries.commits_between queries.commits_last_synced_at queries.sync_failures
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

    import keys: %w[
      operations.remove_tag operations.save_tag queries.all queries.by_id queries.matching queries.usage
    ], from: :tags

    export %w[operations.revoke_client queries.connected_clients]
  end
end
