# frozen_string_literal: true

module Tasks
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/tasks"), namespace: Tasks)

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[
      github.client linear.client operations.record_issue_sync_outcome operations.record_linear_issue_sync_outcome
    ], from: :record

    export %w[
      operations.add_task_comment operations.cancel_task operations.capture_task operations.complete_task
      operations.current_sprint operations.delete_task operations.delete_task_comment operations.drop_sprint
      operations.edit_task_comment operations.link_tasks operations.move_task operations.plan_sprint
      operations.place_task operations.queue_issue_sync operations.reopen_task operations.reorder_task
      operations.save_task operations.schedule_task operations.start_task operations.unlink_task
      queries.counted_sprints_between queries.find_tasks queries.finished_task_counts queries.link_targets
      queries.list_finished_tasks queries.list_tasks queries.open_task_counts queries.open_tasks
      queries.open_tasks_in_list queries.planned_tasks queries.sprints_after queries.sprints_between
      queries.task_by_id queries.task_comments queries.tasks_in_sprint
    ]
  end
end
