# frozen_string_literal: true

require_relative "operations"

module API
  class Slice < Hanami::Slice
    config.no_auto_register_paths += %w[serializers]
    config.shared_app_component_keys += %w[honeybadger.agent]

    import keys: %w[
      operations.snooze_attention repos.activity_queries repos.attention_queries repos.review_queries
    ], from: :activity

    import keys: %w[
      operations.add_memory_fact operations.change_memory_scope operations.create_artifact
      operations.create_memory_file operations.delete_artifact operations.delete_memory_file
      operations.describe_memory_file operations.edit_memory_fact operations.end_session operations.load_memory
      operations.record_loads operations.remove_memory_fact operations.restore_artifact_version
      operations.revert_memory_event operations.search_memory operations.start_session operations.update_artifact
      repos.agent_session_queries repos.artifact_queries repos.memory_file_queries
    ], from: :agents

    import keys: %w[
      repos.analytics_event_queries repos.analytics_hour_queries repos.analytics_page_queries
      repos.analytics_rollup_queries repos.feed_fetch_queries repos.post_reader_queries
    ], from: :analytics

    import keys: %w[repos.calendar_day_queries], from: :calendar

    import keys: %w[
      operations.act_on_messages
      operations.change_thread
      operations.snooze_messages
      operations.wake_message
      repos.message_queries
    ], from: :mail

    import keys: %w[
      operations.add_decision_comment operations.add_decision_option operations.delete_decision_comment
      operations.delete_decision_option operations.drop_decision operations.edit_decision
      operations.edit_decision_comment operations.edit_decision_option operations.open_decision
      operations.reopen_decision operations.resolve_decision repos.decision_queries
    ], from: :decisions

    import keys: %w[repos.health_queries], from: :health

    import keys: %w[operations.link_records operations.unlink_records repos.record_link_queries], from: :links

    import keys: %w[operations.read_photo operations.upload_photo], from: :media

    import keys: %w[
      operations.act_on_posts operations.compose_announcement operations.delete_post operations.publish_draft
      operations.revise_edit_note operations.save_post operations.save_post_seo repos.post_figure_queries
      repos.post_queries
    ], from: :posts

    import keys: %w[
      operations.add_work_entry operations.archive_project operations.delete_work_entry operations.restore_project
      operations.save_project repos.project_queries repos.work_entry_queries
    ], from: :projects

    import keys: %w[
      operations.delete_journal_entry operations.save_journal_entry operations.save_review_note
      operations.queue_commit_import operations.update_journal_entry repos.commit_queries repos.journal_entry_queries
      repos.pull_request_queries repos.review_note_queries repos.sync_state_queries
    ], from: :record

    import keys: %w[
      operations.change_saved_view operations.create_saved_view operations.delete_saved_view
      repos.saved_view_queries
    ], from: :saved_views

    import keys: %w[repos.search_queries], from: :search

    import keys: %w[
      operations.add_shares_to_group operations.group_shares operations.name_share_group operations.rename_share_file
      operations.ungroup_share_file operations.upload_share operations.upload_share_group repos.share_group_queries
      repos.share_queries
    ], from: :shares

    import keys: %w[
      operations.act_on_webmentions operations.compose_social_post operations.delete_person
      operations.delete_social_post operations.list_target_accounts operations.mark_webmention_seen
      operations.measure_parts operations.moderate_webmention operations.remove_trusted_author operations.save_person
      operations.search_accounts operations.snooze_webmentions operations.update_webmention_settings
      operations.wake_webmention repos.person_queries
      repos.social_post_queries repos.webmention_queries
    ], from: :social

    import keys: %w[repos.timing_report_queries], from: :performance

    import keys: %w[operations.record_sighting], from: :security

    import keys: %w[
      operations.accept_suggestion_edits operations.reject_suggestion_edits operations.replace_post_edits
      operations.replace_social_post_edits repos.suggestion_queries
    ], from: :suggestions

    import keys: %w[operations.remove_tag operations.save_tag repos.tag_queries], from: :tags

    import keys: %w[
      operations.act_on_tasks operations.add_repo_rule operations.add_work_session
      operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task operations.current_sprint operations.delete_task operations.delete_task_comment
      operations.delete_task_rule operations.delete_work_session operations.drop_sprint operations.edit_task_comment
      operations.edit_work_session operations.link_tasks operations.mark_task_seen
      operations.mark_tasks_seen operations.move_task
      operations.pause_task operations.pause_task_series operations.place_task operations.plan_sprint
      operations.queue_issue_sync operations.reopen_task operations.reorder_task operations.resume_task_series
      operations.save_task operations.save_task_rule
      operations.schedule_task operations.set_task_total operations.snooze_tasks operations.stage_task
      operations.start_task
      operations.unlink_task operations.wake_task
      repos.sprint_queries repos.task_comment_queries repos.task_queries repos.task_rule_queries
      repos.task_series_queries repos.task_source_queries repos.task_timeline_queries repos.time_report_queries
    ], from: :tasks

    export [
      *OperationTable::ENDPOINTS.map { "endpoints.#{it}" }, # rubocop:disable Hanami/SliceExports
      "operations.clear_inbox", "operations.mint_token", "operations.revoke_token", "operations.snooze_inbox",
      "operations.snooze_inbox_row", "operations.summarize_analytics", "operations.summarize_page",
      "operations.wake_inbox_row", "repos.api_token_queries", "repos.client_queries", "repos.inbox_queries",
    ]
  end
end
