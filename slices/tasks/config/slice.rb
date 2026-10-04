# frozen_string_literal: true

module Tasks
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/tasks"), namespace: Tasks)

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[queries.linkable_projects], from: :projects

    import keys: %w[
      github.client linear.client operations.record_issue_sync_outcome operations.record_linear_issue_sync_outcome
    ], from: :record

    export %w[
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task
      operations.current_sprint operations.delete_task operations.delete_task_comment operations.delete_task_tag_rule
      operations.delete_work_session
      operations.drop_sprint operations.edit_task_comment operations.edit_work_session operations.link_tasks
      operations.mark_task_seen operations.move_task
      operations.plan_sprint operations.place_task operations.queue_issue_sync operations.reopen_task
      operations.reorder_task operations.save_task operations.save_task_tag_rule operations.schedule_task
      operations.set_task_total
      operations.start_task
      operations.unlink_task
      queries.counted_sprints_between queries.find_tasks queries.finished_task_counts queries.link_targets
      queries.linkable_tasks
      queries.list_finished_tasks queries.list_tasks queries.open_task_counts queries.open_tasks
      queries.open_tasks_in_list queries.planned_tasks queries.sprints_after queries.sprints_between
      queries.task_by_id queries.task_comments queries.task_tag_rules queries.task_timeline
      queries.tasks_in_progress
      queries.tasks_in_sprint queries.time_report queries.unseen_task_count queries.unseen_tasks
    ]
  end
end
