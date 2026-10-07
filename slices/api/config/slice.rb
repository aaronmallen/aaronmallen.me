# frozen_string_literal: true

module API
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/api"), namespace: API)

    config.no_auto_register_paths += %w[serializers]

    config.actions.csrf_protection = false

    import keys: %w[
      operations.snooze_attention repos.activity_queries repos.attention_queries repos.review_queries
    ], from: :activity

    import keys: %w[repos.analytics_rollup_queries repos.post_reader_queries], from: :analytics

    import keys: %w[
      operations.act_on_messages
      operations.mark_message
      operations.snooze_messages
      operations.wake_message
      repos.message_queries
    ], from: :contact

    import keys: %w[
      operations.add_decision_comment operations.add_decision_option operations.delete_decision_comment
      operations.delete_decision_option operations.drop_decision operations.edit_decision
      operations.edit_decision_comment operations.edit_decision_option operations.open_decision
      operations.reopen_decision operations.resolve_decision repos.decision_queries
    ], from: :decisions

    import keys: %w[operations.link_records operations.unlink_records repos.record_link_queries], from: :links

    import keys: %w[operations.upload_photo], from: :media

    import keys: %w[
      operations.act_on_posts operations.publish_draft operations.revise_edit_note repos.post_queries
    ], from: :posts

    import keys: %w[repos.project_queries repos.work_entry_queries], from: :projects

    import keys: %w[
      operations.delete_journal_entry operations.save_journal_entry operations.save_review_note
      operations.update_journal_entry repos.commit_queries repos.journal_entry_queries repos.review_note_queries
    ], from: :record

    import keys: %w[
      operations.change_saved_view operations.create_saved_view operations.delete_saved_view
      repos.saved_view_queries
    ], from: :saved_views

    import keys: %w[repos.search_queries], from: :search

    import keys: %w[
      operations.act_on_webmentions operations.delete_person operations.mark_webmention_seen operations.measure_parts
      operations.save_person operations.search_accounts operations.snooze_webmentions operations.wake_webmention
      repos.person_queries repos.social_post_queries repos.webmention_queries
    ], from: :social

    import keys: %w[operations.record_sighting], from: :security

    import keys: %w[repos.suggestion_queries], from: :suggestions

    import keys: %w[repos.tag_queries], from: :tags

    import keys: %w[
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task operations.current_sprint operations.delete_task operations.delete_task_comment
      operations.delete_task_rule operations.delete_work_session operations.drop_sprint operations.edit_task_comment
      operations.edit_work_session operations.link_tasks operations.mark_task_seen operations.move_task
      operations.pause_task operations.place_task operations.plan_sprint operations.queue_issue_sync
      operations.reopen_task operations.reorder_task operations.save_task operations.save_task_rule
      operations.schedule_task operations.set_task_total operations.snooze_tasks operations.start_task
      operations.unlink_task operations.wake_task
      repos.sprint_queries repos.task_comment_queries repos.task_queries repos.task_rule_queries
      repos.task_source_queries repos.time_report_queries
    ], from: :tasks

    export %w[
      endpoints.add_decision_comment endpoints.add_decision_option endpoints.add_task_comment
      endpoints.approve_webmentions endpoints.cancel_task endpoints.cancel_tasks endpoints.capture_task
      endpoints.clear_inbox
      endpoints.complete_task endpoints.complete_tasks endpoints.create_journal_entry endpoints.create_person
      endpoints.create_saved_view endpoints.create_task_rule endpoints.delete_decision_comment
      endpoints.delete_decision_option endpoints.delete_journal_entry endpoints.delete_messages endpoints.delete_person
      endpoints.delete_posts endpoints.delete_saved_view endpoints.delete_task endpoints.delete_task_comment
      endpoints.delete_task_rule endpoints.delete_tasks endpoints.delete_work_session endpoints.drop_decision
      endpoints.drop_sprint endpoints.edit_decision endpoints.edit_decision_comment endpoints.edit_decision_option
      endpoints.edit_task_comment endpoints.ignore_webmentions endpoints.link_records endpoints.link_tasks
      endpoints.list_attention endpoints.list_calendar endpoints.list_decisions endpoints.list_inbox
      endpoints.list_journal_entries endpoints.list_links endpoints.list_people endpoints.list_saved_views
      endpoints.list_sprints endpoints.list_task_rules endpoints.list_tasks endpoints.list_webmentions
      endpoints.mark_messages_read endpoints.mark_messages_unread endpoints.mark_task_seen
      endpoints.mark_webmentions_spam endpoints.move_task endpoints.move_tasks endpoints.open_decision
      endpoints.pause_task endpoints.plan_sprint endpoints.publish_post endpoints.read_activity endpoints.read_commit
      endpoints.read_current_sprint endpoints.read_decision endpoints.read_journal_entry endpoints.read_person
      endpoints.read_post endpoints.read_project endpoints.read_review endpoints.read_saved_view
      endpoints.read_social_post endpoints.read_tag endpoints.read_task endpoints.read_time_report
      endpoints.read_webmention endpoints.read_work_entry endpoints.reopen_decision endpoints.reopen_task
      endpoints.reorder_task endpoints.resolve_decision endpoints.save_review_note endpoints.save_task
      endpoints.schedule_task endpoints.search endpoints.search_accounts endpoints.set_task_total
      endpoints.snooze_attention
      endpoints.snooze_inbox
      endpoints.snooze_inbox_row
      endpoints.start_task endpoints.summarize_activity endpoints.sync_issues
      endpoints.tag_decision endpoints.tag_posts endpoints.tag_tasks endpoints.unlink_records endpoints.unlink_task
      endpoints.untag_decision endpoints.untag_tasks endpoints.update_journal_entry endpoints.update_person
      endpoints.update_post_edit_note endpoints.update_saved_view endpoints.update_task_rule
      endpoints.update_work_session endpoints.upload_photo
      endpoints.wake_inbox_row
      operations.clear_inbox
      operations.mint_token operations.revoke_token
      operations.snooze_inbox
      operations.snooze_inbox_row
      operations.wake_inbox_row
      repos.api_token_queries repos.calendar_queries repos.inbox_queries repos.post_figure_queries
    ]
  end
end
