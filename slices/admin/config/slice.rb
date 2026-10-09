# frozen_string_literal: true

module Admin
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/admin"), namespace: Admin)

    ROBOTS = "noindex, nofollow"

    config.shared_app_component_keys += %w[assets honeybadger.agent]

    config.no_auto_register_paths += %w[helpers]

    config.actions.default_headers.merge!("Cache-Control" => "private, no-store", "X-Robots-Tag" => ROBOTS)

    config.actions.csrf_protection = true

    config.actions.sessions = Blog::SessionCookie.store

    import keys: %w[
      operations.snooze_attention repos.activity_queries repos.attention_queries repos.review_queries
    ], from: :activity

    import keys: %w[
      repos.analytics_event_queries repos.analytics_page_queries repos.analytics_rollup_queries repos.country_queries
      repos.feed_fetch_queries repos.post_reader_queries
    ], from: :analytics

    import keys: %w[
      operations.clear_inbox
      operations.mint_token operations.revoke_token
      operations.snooze_inbox
      operations.snooze_inbox_row
      operations.wake_inbox_row
      repos.api_token_queries repos.calendar_queries repos.inbox_queries repos.post_figure_queries
    ], from: :api

    import keys: %w[
      operations.add_decision_comment operations.add_decision_option operations.delete_decision_comment
      operations.drop_decision operations.edit_decision operations.edit_decision_comment
      operations.edit_decision_option operations.open_decision operations.reopen_decision
      operations.resolve_decision repos.decision_queries
    ], from: :decisions

    import keys: %w[
      operations.act_on_messages operations.delete_message operations.label_message operations.mark_message
      operations.wake_message repos.message_queries
    ], from: :contact

    import keys: %w[
      github.client linear.client operations.delete_journal_entry operations.queue_commit_import
      operations.save_journal_entry operations.save_review_note operations.update_journal_entry repos.commit_queries
      repos.journal_entry_queries repos.review_note_queries repos.sync_state_queries
    ], from: :record

    import keys: %w[
      operations.link_records operations.unlink_records repos.record_link_queries
    ], from: :links

    import keys: %w[operations.upload_photo store.client], from: :media

    import keys: %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry
      operations.restore_project operations.save_project repos.project_queries repos.work_entry_queries
    ], from: :projects

    import keys: %w[
      operations.act_on_posts operations.compose_announcement operations.delete_post operations.move_post
      operations.publish_draft operations.revise_edit_note operations.save_post repos.post_queries
    ], from: :posts

    import keys: %w[operations.remove_tag operations.save_tag repos.tag_queries], from: :tags

    import keys: %w[
      operations.change_saved_view operations.create_saved_view operations.delete_saved_view
      operations.rename_saved_view repos.saved_view_queries
    ], from: :saved_views

    import keys: %w[repos.search_queries], from: :search

    import keys: %w[
      operations.record_sign_in
      repos.sighting_queries
      repos.sign_in_queries
    ], from: :security

    import keys: %w[
      operations.add_connection operations.remove_connection repos.connection_queries repos.definition_queries
    ], from: :services

    import keys: %w[
      networks.all operations.act_on_webmentions operations.compose_social_post operations.delete_person
      operations.delete_social_post operations.expand_for_network operations.moderate_webmention
      operations.move_social_post operations.resolve_mentions operations.save_person operations.search_accounts
      operations.update_webmention_settings repos.person_queries repos.social_post_queries repos.webmention_queries
    ], from: :social

    import keys: %w[
      operations.accept_suggestion_edits operations.reject_suggestion_edits repos.suggestion_queries
    ], from: :suggestions

    import keys: %w[
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task operations.current_sprint operations.delete_task operations.delete_task_comment
      operations.delete_task_rule operations.delete_work_session operations.drop_sprint operations.edit_task_comment
      operations.edit_work_session operations.link_repo_tasks operations.link_tasks operations.mark_task_seen
      operations.move_task operations.pause_task operations.place_task operations.plan_sprint
      operations.queue_issue_sync operations.reopen_task operations.save_task operations.save_task_rule
      operations.schedule_task operations.set_task_total operations.start_task operations.unlink_task
      repos.sprint_queries repos.task_queries repos.task_rule_queries repos.task_source_queries
      repos.time_report_queries
    ], from: :tasks

    import keys: %w[operations.revoke_client repos.oauth_client_queries], from: :mcp

    export %w[auth.session_reader]
  end
end
