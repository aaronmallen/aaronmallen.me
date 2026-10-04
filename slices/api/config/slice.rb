# frozen_string_literal: true

module API
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/api"), namespace: API)

    config.no_auto_register_paths += %w[serializers]

    config.actions.csrf_protection = false

    import keys: %w[operations.snooze_attention queries.review queries.stalled_list], from: :activity

    import keys: %w[operations.act_on_messages queries.count_with_status queries.unread_messages], from: :contact

    import keys: %w[
      operations.add_decision_comment operations.add_decision_option operations.delete_decision_comment
      operations.delete_decision_option operations.drop_decision operations.edit_decision
      operations.edit_decision_comment operations.edit_decision_option operations.open_decision
      operations.reopen_decision operations.resolve_decision queries.by_id queries.comments queries.find_decisions
      queries.timeline
    ], from: :decisions

    import keys: %w[operations.link_records operations.unlink_records queries.record_links], from: :links

    import keys: %w[operations.act_on_posts queries.calendar_posts], from: :posts

    import keys: %w[
      operations.delete_journal_entry operations.save_journal_entry operations.update_journal_entry
      queries.journal_days_between queries.journal_entries_between queries.journal_entry_by_id
    ], from: :record

    import keys: %w[
      operations.change_saved_view operations.create_saved_view operations.delete_saved_view
      operations.rename_saved_view queries.all queries.by_id
    ], from: :saved_views

    import keys: %w[queries.search], from: :search

    import keys: %w[
      operations.act_on_webmentions queries.calendar_social_posts queries.pending_webmention_count
      queries.pending_webmentions
    ], from: :social

    import keys: %w[
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task operations.current_sprint operations.delete_task operations.delete_work_session
      operations.drop_sprint operations.edit_work_session operations.link_tasks operations.mark_task_seen
      operations.move_task operations.plan_sprint operations.reopen_task operations.reorder_task operations.save_task
      operations.schedule_task operations.set_task_total operations.start_task operations.unlink_task
      queries.counted_sprints_between queries.find_tasks queries.sprints_between queries.task_by_id
      queries.task_comments queries.task_timeline queries.tasks_in_sprint queries.time_report queries.unseen_task_count
      queries.unseen_tasks
    ], from: :tasks

    export %w[
      endpoints.add_decision_comment endpoints.add_decision_option endpoints.add_task_comment
      endpoints.approve_webmentions endpoints.cancel_task endpoints.cancel_tasks endpoints.capture_task
      endpoints.complete_task endpoints.complete_tasks endpoints.create_journal_entry endpoints.create_saved_view
      endpoints.delete_decision_comment endpoints.delete_decision_option endpoints.delete_journal_entry
      endpoints.delete_messages endpoints.delete_posts endpoints.delete_saved_view endpoints.delete_task
      endpoints.delete_tasks endpoints.delete_work_session endpoints.drop_decision endpoints.drop_sprint
      endpoints.edit_decision endpoints.edit_decision_comment endpoints.edit_decision_option
      endpoints.ignore_webmentions endpoints.link_records endpoints.link_tasks endpoints.list_attention
      endpoints.list_decisions endpoints.list_inbox endpoints.list_journal_entries endpoints.list_links
      endpoints.list_saved_views endpoints.list_sprints endpoints.list_tasks endpoints.mark_messages_read
      endpoints.mark_messages_unread endpoints.mark_task_seen endpoints.mark_webmentions_spam endpoints.move_task
      endpoints.move_tasks endpoints.open_decision endpoints.pause_task endpoints.plan_sprint
      endpoints.read_current_sprint endpoints.read_decision endpoints.read_journal_entry endpoints.read_review
      endpoints.read_task endpoints.read_time_report endpoints.reopen_decision endpoints.reopen_task
      endpoints.reorder_task endpoints.resolve_decision endpoints.save_task endpoints.schedule_task endpoints.search
      endpoints.set_task_total endpoints.snooze_attention endpoints.start_task endpoints.tag_decision
      endpoints.tag_posts endpoints.tag_tasks
      endpoints.unlink_records endpoints.unlink_task endpoints.untag_decision endpoints.untag_tasks
      endpoints.update_journal_entry endpoints.update_saved_view endpoints.update_work_session operations.mint_token
      operations.revoke_token queries.calendar queries.inbox queries.inbox_count queries.live_tokens
    ]
  end
end
