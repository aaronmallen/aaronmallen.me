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
      endpoints.add_decision_comment endpoints.add_decision_option endpoints.add_task_comment
      endpoints.approve_webmentions endpoints.cancel_task endpoints.cancel_tasks endpoints.capture_task
      endpoints.complete_task endpoints.complete_tasks endpoints.create_journal_entry endpoints.create_person
      endpoints.create_saved_view endpoints.create_task_tag_rule endpoints.delete_decision_comment
      endpoints.delete_decision_option endpoints.delete_journal_entry endpoints.delete_messages endpoints.delete_person
      endpoints.delete_posts endpoints.delete_saved_view endpoints.delete_task endpoints.delete_task_comment
      endpoints.delete_task_tag_rule endpoints.delete_tasks endpoints.delete_work_session endpoints.drop_decision
      endpoints.drop_sprint endpoints.edit_decision endpoints.edit_decision_comment endpoints.edit_decision_option
      endpoints.edit_task_comment endpoints.ignore_webmentions endpoints.link_records endpoints.link_tasks
      endpoints.list_attention endpoints.list_calendar endpoints.list_decisions endpoints.list_inbox
      endpoints.list_journal_entries endpoints.list_links endpoints.list_people endpoints.list_saved_views
      endpoints.list_sprints endpoints.list_task_tag_rules endpoints.list_tasks endpoints.list_webmentions
      endpoints.mark_messages_read endpoints.mark_messages_unread endpoints.mark_task_seen
      endpoints.mark_webmentions_spam endpoints.move_task endpoints.move_tasks endpoints.open_decision
      endpoints.pause_task endpoints.plan_sprint endpoints.publish_post endpoints.read_activity endpoints.read_commit
      endpoints.read_current_sprint endpoints.read_decision endpoints.read_journal_entry endpoints.read_person
      endpoints.read_post endpoints.read_project endpoints.read_review endpoints.read_saved_view
      endpoints.read_social_post endpoints.read_task endpoints.read_time_report endpoints.read_webmention
      endpoints.read_work_entry endpoints.reopen_decision endpoints.reopen_task endpoints.reorder_task
      endpoints.resolve_decision endpoints.save_review_note endpoints.save_task endpoints.schedule_task endpoints.search
      endpoints.search_accounts endpoints.set_task_total endpoints.snooze_attention endpoints.start_task
      endpoints.summarize_activity endpoints.sync_issues endpoints.tag_decision endpoints.tag_posts endpoints.tag_tasks
      endpoints.unlink_records endpoints.unlink_task endpoints.untag_decision endpoints.untag_tasks
      endpoints.update_journal_entry endpoints.update_person endpoints.update_post_edit_note endpoints.update_saved_view
      endpoints.update_task_tag_rule endpoints.update_work_session endpoints.upload_photo
    ], from: :api

    import keys: %w[
      operations.hash_visitor queries.clicks_between queries.devices_between queries.feed_subscribers_between
      queries.first_days queries.hourly_between queries.navigation_between queries.page_between queries.reach_between
      queries.read_spread_between queries.read_throughs_between queries.readers_by_path queries.scroll_depths_between
      queries.sources_between queries.summary_between queries.weekday_hours
    ], from: :analytics

    import keys: %w[operations.mark_message queries.by_id queries.received_between], from: :contact

    import keys: %w[
      operations.compose_announcement operations.delete_post operations.save_post operations.save_post_seo queries.by_id
      queries.by_ids queries.dated_between queries.published_by_slug
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
      operations.update_webmention_settings queries.editable_social_post queries.pending_webmention_count
      queries.social_posts_dated_between queries.unsent_social_posts queries.webmention_settings
      queries.webmentions_received_between queries.webmentions_received_by_post
    ], from: :social

    import keys: %w[
      operations.accept_suggestion_edits operations.reject_suggestion_edits operations.replace_post_edits
      operations.replace_social_post_edits queries.by_id queries.created_between
    ], from: :suggestions

    import keys: %w[
      operations.remove_tag operations.save_tag queries.all queries.by_id queries.matching queries.usage
    ], from: :tags

    export %w[operations.revoke_client queries.connected_clients]
  end
end
