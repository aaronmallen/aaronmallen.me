# frozen_string_literal: true

module Admin
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/admin"), namespace: Admin)

    ROBOTS = "noindex, nofollow"

    config.shared_app_component_keys += %w[assets]

    config.actions.default_headers.merge!("Cache-Control" => "private, no-store", "X-Robots-Tag" => ROBOTS)

    config.actions.csrf_protection = true

    config.actions.sessions = Blog::SessionCookie.store

    import keys: %w[
      operations.snooze_attention queries.activity_between queries.activity_counts queries.activity_counts_by_day
      queries.activity_day_count queries.review queries.stalled_list
    ], from: :activity

    import keys: %w[
      queries.country_counts queries.country_database_failure queries.devices_between queries.page_between
      queries.reach_between queries.read_throughs_between queries.readers_by_path queries.referrer_counts
      queries.rollups_between queries.scroll_depths_between queries.sources_between queries.top_paths
      queries.unrolled_summaries queries.view_totals queries.views_by_path queries.views_by_post
      queries.visitors_for_day queries.weekday_hours
    ], from: :analytics

    import keys: %w[
      operations.mint_token operations.revoke_token queries.calendar queries.inbox queries.inbox_count
      queries.live_tokens
    ], from: :api

    import keys: %w[
      operations.add_decision_comment operations.add_decision_option operations.delete_decision_comment
      operations.drop_decision operations.edit_decision operations.edit_decision_comment
      operations.edit_decision_option operations.open_decision operations.reopen_decision
      operations.resolve_decision queries.by_id queries.by_status queries.count_by_status queries.timeline
    ], from: :decisions

    import keys: %w[
      operations.act_on_messages operations.mark_message queries.by_id queries.by_status queries.count_with_status
    ], from: :contact

    import keys: %w[
      github.client operations.delete_journal_entry operations.queue_commit_import operations.save_journal_entry
      operations.update_journal_entry queries.commit_by_id queries.commit_totals_today queries.commits_last_synced_at
      queries.commits_today queries.journal_days queries.journal_entries_today queries.journal_entry_count
      queries.journal_streak queries.journal_word_count queries.recent_commit_repos
      queries.sync_failures
    ], from: :record

    import keys: %w[
      operations.link_records operations.unlink_records queries.find_records queries.record_links
    ], from: :links

    import keys: %w[operations.upload_photo store.client], from: :media

    import keys: %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry operations.move_project
      operations.restore_project operations.save_project queries.archived queries.by_id queries.live
      queries.work_entries
    ], from: :projects

    import keys: %w[
      operations.act_on_posts operations.compose_announcement operations.delete_post operations.move_post
      operations.revise_edit_note
      operations.save_post queries.by_filter queries.by_id queries.by_ids queries.by_status queries.count_by_status
      queries.edits_newest_first queries.scheduled queries.summaries
    ], from: :posts

    import keys: %w[
      operations.remove_tag operations.save_tag queries.matching queries.matching_count queries.usage
    ], from: :tags

    import keys: %w[
      operations.change_saved_view operations.create_saved_view operations.delete_saved_view
      operations.rename_saved_view queries.all
    ], from: :saved_views

    import keys: %w[queries.search], from: :search

    import keys: %w[
      networks.all operations.act_on_webmentions operations.compose_social_post operations.delete_person
      operations.delete_social_post operations.moderate_webmention operations.move_social_post operations.save_person
      operations.update_webmention_settings
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
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task
      operations.current_sprint operations.delete_task operations.delete_task_comment
      operations.delete_work_session operations.drop_sprint operations.edit_task_comment
      operations.edit_work_session operations.link_tasks operations.mark_task_seen operations.move_task
      operations.plan_sprint
      operations.place_task operations.queue_issue_sync operations.reopen_task
      operations.save_task operations.schedule_task operations.set_task_total operations.start_task
      operations.unlink_task
      queries.finished_task_counts queries.link_targets queries.list_finished_tasks queries.list_tasks
      queries.open_task_counts queries.open_tasks_in_list queries.planned_tasks
      queries.sprints_after queries.task_by_id queries.task_timeline queries.tasks_in_progress
      queries.tasks_in_sprint queries.time_report
    ], from: :tasks

    import keys: %w[operations.revoke_client queries.connected_clients], from: :mcp

    export %w[auth.session_reader]
  end
end
