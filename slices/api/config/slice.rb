# frozen_string_literal: true

module API
  class Slice < Hanami::Slice
    config.no_auto_register_paths += %w[helpers serializers]

    config.actions.csrf_protection = false

    import keys: %w[
      operations.snooze_attention repos.activity_queries repos.attention_queries repos.review_queries
    ], from: :activity

    import keys: %w[
      repos.analytics_event_queries repos.analytics_page_queries repos.analytics_rollup_queries repos.feed_fetch_queries
      repos.post_reader_queries
    ], from: :analytics

    import keys: %w[repos.calendar_day_queries], from: :calendar

    import keys: %w[
      operations.act_on_messages
      operations.mark_message
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
      operations.upload_share operations.upload_share_group repos.share_group_queries repos.share_queries
    ], from: :shares

    import keys: %w[
      operations.act_on_webmentions operations.compose_social_post operations.delete_person
      operations.delete_social_post operations.list_target_accounts operations.mark_webmention_seen
      operations.measure_parts operations.moderate_webmention operations.save_person
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
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task operations.current_sprint operations.delete_task operations.delete_task_comment
      operations.delete_task_rule operations.delete_work_session operations.drop_sprint operations.edit_task_comment
      operations.edit_work_session operations.link_repo_tasks operations.link_tasks operations.mark_task_seen
      operations.move_task
      operations.pause_task operations.pause_task_series operations.place_task operations.plan_sprint
      operations.queue_issue_sync operations.reopen_task operations.reorder_task operations.resume_task_series
      operations.save_task operations.save_task_rule
      operations.schedule_task operations.set_task_total operations.snooze_tasks operations.stage_task
      operations.start_task
      operations.unlink_task operations.wake_task
      repos.sprint_queries repos.task_comment_queries repos.task_queries repos.task_rule_queries
      repos.task_series_queries repos.task_source_queries repos.time_report_queries
    ], from: :tasks

    export %w[
      endpoints.add_work_entry endpoints.archive_project endpoints.create_project endpoints.delete_work_entry
      endpoints.list_projects endpoints.list_work_entries endpoints.restore_project endpoints.update_project
      endpoints.create_tag endpoints.list_tags endpoints.remove_tag endpoints.update_tag
      endpoints.moderate_webmention endpoints.read_webmention_settings endpoints.update_webmention_settings
      endpoints.import_commits endpoints.list_api_tokens endpoints.list_commits endpoints.list_pull_requests
      endpoints.read_sync_state
      endpoints.accept_suggestion_edits endpoints.list_suggestions endpoints.reject_suggestion_edits
      endpoints.suggest_edits
      endpoints.compose_announcement endpoints.create_post endpoints.delete_post endpoints.list_posts
      endpoints.update_post endpoints.write_post_seo
      endpoints.list_mail_threads endpoints.mark_mail_thread endpoints.read_mail_thread
      endpoints.list_clients endpoints.read_analytics endpoints.read_performance endpoints.read_photo
      endpoints.list_share_groups endpoints.list_shares endpoints.read_share endpoints.read_share_group
      endpoints.upload_share endpoints.upload_share_group
      endpoints.add_decision_comment endpoints.add_decision_option endpoints.add_task_comment
      endpoints.approve_webmentions endpoints.cancel_task endpoints.cancel_tasks endpoints.capture_task
      endpoints.clear_inbox
      endpoints.complete_task endpoints.complete_tasks endpoints.create_journal_entry endpoints.create_person
      endpoints.create_saved_view endpoints.create_social_post endpoints.create_task_rule
      endpoints.delete_decision_comment
      endpoints.delete_decision_option endpoints.delete_journal_entry endpoints.delete_mail_threads
      endpoints.delete_person
      endpoints.delete_posts endpoints.delete_saved_view endpoints.delete_social_post endpoints.delete_task
      endpoints.delete_task_comment
      endpoints.delete_task_rule endpoints.delete_tasks endpoints.delete_work_session endpoints.drop_decision
      endpoints.drop_sprint endpoints.edit_decision endpoints.edit_decision_comment endpoints.edit_decision_option
      endpoints.edit_task_comment endpoints.ignore_webmentions endpoints.link_records endpoints.link_tasks
      endpoints.list_attention endpoints.list_calendar endpoints.list_decisions endpoints.list_inbox
      endpoints.list_journal_entries endpoints.list_links endpoints.list_people endpoints.list_saved_views
      endpoints.list_social_posts
      endpoints.list_sprints endpoints.list_task_rules endpoints.list_task_series endpoints.list_tasks
      endpoints.list_webmentions
      endpoints.mark_mail_threads_read endpoints.mark_mail_threads_unread endpoints.mark_task_seen
      endpoints.mark_webmentions_spam endpoints.move_task endpoints.move_tasks endpoints.open_decision
      endpoints.pause_task endpoints.pause_task_series endpoints.plan_sprint endpoints.publish_post
      endpoints.read_activity endpoints.read_commit
      endpoints.read_current_sprint endpoints.read_decision endpoints.read_health_days endpoints.read_journal_entry
      endpoints.read_person
      endpoints.read_post endpoints.read_project endpoints.read_pull_request endpoints.read_review
      endpoints.read_saved_view
      endpoints.read_social_post endpoints.read_tag endpoints.read_task endpoints.read_time_report
      endpoints.read_webmention endpoints.read_work_entry endpoints.reopen_decision endpoints.reopen_task
      endpoints.reorder_task endpoints.resolve_decision endpoints.resume_task_series endpoints.save_review_note
      endpoints.save_task
      endpoints.schedule_task endpoints.search endpoints.search_accounts endpoints.send_social_post
      endpoints.set_task_total
      endpoints.snooze_attention
      endpoints.snooze_inbox
      endpoints.snooze_inbox_row
      endpoints.snooze_mail_threads
      endpoints.stage_task
      endpoints.start_task endpoints.summarize_activity endpoints.sync_issues
      endpoints.tag_decision endpoints.tag_posts endpoints.tag_tasks endpoints.unlink_records endpoints.unlink_task
      endpoints.tag_mail_threads
      endpoints.untag_mail_threads
      endpoints.untag_decision endpoints.untag_tasks endpoints.update_journal_entry endpoints.update_person
      endpoints.update_post_edit_note endpoints.update_saved_view endpoints.update_social_post
      endpoints.update_task_rule
      endpoints.update_work_session endpoints.upload_photo
      endpoints.wake_inbox_row
      operations.clear_inbox
      operations.mint_token operations.revoke_token
      operations.snooze_inbox
      operations.snooze_inbox_row
      operations.summarize_analytics operations.summarize_page
      operations.wake_inbox_row
      repos.api_token_queries repos.inbox_queries
    ]
  end
end
