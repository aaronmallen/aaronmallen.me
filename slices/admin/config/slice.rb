# frozen_string_literal: true

module Admin
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/admin"), namespace: Admin)

    ROBOTS = "noindex, nofollow"

    config.shared_app_component_keys += %w[assets]

    config.actions.default_headers.merge!("Cache-Control" => "private, no-store", "X-Robots-Tag" => ROBOTS)

    config.actions.csrf_protection = true

    config.actions.sessions = Blog::SessionCookie.store

    import keys: %w[queries.activity_between queries.activity_counts queries.activity_day_count], from: :activity

    import keys: %w[
      queries.country_counts queries.country_database_failure queries.referrer_counts queries.rollup_for_day
      queries.rollups_between queries.summary_for_day queries.top_paths queries.view_totals queries.views_by_path
      queries.views_by_post queries.visitors_for_day
    ], from: :analytics

    import keys: %w[operations.mint_token operations.revoke_token queries.live_tokens], from: :api

    import keys: %w[operations.mark_message queries.by_status queries.count_with_status], from: :contact

    import keys: %w[
      github.client operations.delete_journal_entry operations.queue_commit_import operations.save_journal_entry
      operations.update_journal_entry queries.commit_by_id queries.commit_totals_today queries.commits_last_synced_at
      queries.commits_today queries.journal_days queries.journal_entries_today queries.journal_entry_count
      queries.journal_streak queries.journal_word_count queries.recent_commit_repos
      queries.sync_failures
    ], from: :record

    import keys: %w[operations.upload_photo store.client], from: :media

    import keys: %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry operations.move_project
      operations.restore_project operations.save_project queries.archived queries.by_id queries.live
      queries.work_entries
    ], from: :projects

    import keys: %w[
      operations.compose_announcement operations.delete_post operations.revise_edit_note operations.save_post
      queries.all queries.by_filter queries.by_id queries.by_ids queries.by_status queries.count_by_status
      queries.edits_newest_first queries.scheduled
    ], from: :posts

    import keys: %w[
      operations.remove_tag operations.save_tag queries.matching queries.matching_count queries.usage
    ], from: :tags

    import keys: %w[
      networks.all operations.compose_social_post operations.delete_person operations.delete_social_post
      operations.moderate_webmention operations.save_person operations.update_webmention_settings
      queries.editable_social_post queries.mention_directory queries.pending_webmention_count
      queries.pending_webmentions queries.people queries.person_by_id queries.queued_social_posts
      queries.received_webmention_count
      queries.social_post_by_id queries.social_post_counts_by_status queries.social_posts_by_filter
      queries.webmention_counts_by_post queries.webmention_counts_by_status queries.webmention_settings
      queries.webmentions_by_status queries.webmentions_received_between queries.webmentions_received_by_post
    ], from: :social

    import keys: %w[
      operations.accept_suggestion_edits operations.reject_edits queries.for_post queries.for_social_post
      queries.open_counts_for_social_posts
    ], from: :suggestions

    import keys: %w[
      operations.add_task_comment operations.cancel_task operations.capture_task operations.complete_task
      operations.current_sprint operations.delete_task operations.delete_task_comment operations.drop_sprint
      operations.edit_task_comment operations.link_tasks operations.move_task operations.plan_sprint
      operations.place_task operations.queue_issue_sync operations.reopen_task
      operations.save_task operations.schedule_task operations.start_task operations.unlink_task
      queries.finished_task_counts queries.link_targets queries.list_finished_tasks queries.list_tasks
      queries.open_task_counts queries.open_tasks queries.open_tasks_in_list queries.planned_tasks
      queries.sprints_after queries.task_by_id queries.task_comments queries.tasks_in_sprint
    ], from: :tasks

    import keys: %w[operations.revoke_client queries.connected_clients], from: :mcp

    export %w[auth.session_reader]
  end
end
