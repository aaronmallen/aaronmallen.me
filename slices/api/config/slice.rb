# frozen_string_literal: true

module API
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/api"), namespace: API)

    config.no_auto_register_paths += %w[serializers]

    config.actions.csrf_protection = false

    import keys: %w[queries.calendar_posts], from: :posts

    import keys: %w[
      operations.delete_journal_entry operations.save_journal_entry operations.update_journal_entry
      queries.journal_days_between queries.journal_entries_between queries.journal_entry_by_id
    ], from: :record

    import keys: %w[queries.calendar_social_posts], from: :social

    import keys: %w[
      operations.add_task_comment operations.cancel_task operations.capture_task operations.complete_task
      operations.current_sprint operations.delete_task operations.drop_sprint operations.link_tasks operations.move_task
      operations.plan_sprint operations.reopen_task operations.reorder_task operations.save_task
      operations.schedule_task operations.start_task operations.unlink_task queries.counted_sprints_between
      queries.find_tasks queries.sprints_between queries.task_by_id queries.task_comments queries.tasks_in_sprint
    ], from: :tasks

    export %w[
      endpoints.add_task_comment endpoints.cancel_task endpoints.capture_task endpoints.complete_task
      endpoints.create_journal_entry endpoints.delete_journal_entry endpoints.delete_task endpoints.drop_sprint
      endpoints.link_tasks endpoints.list_journal_entries endpoints.list_sprints endpoints.list_tasks
      endpoints.move_task endpoints.plan_sprint endpoints.read_current_sprint endpoints.read_journal_entry
      endpoints.read_task endpoints.reopen_task endpoints.reorder_task endpoints.save_task endpoints.schedule_task
      endpoints.start_task endpoints.unlink_task endpoints.update_journal_entry
      operations.mint_token operations.revoke_token queries.calendar queries.live_tokens
    ]
  end
end
