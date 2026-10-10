# frozen_string_literal: true

module Tasks
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/tasks"), namespace: Tasks)

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[repos.project_queries], from: :projects

    import keys: %w[github.client linear.client operations.record_sync_outcome], from: :record

    export %w[
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.complete_task operations.current_sprint operations.delete_task operations.delete_task_comment
      operations.delete_task_rule operations.delete_work_session operations.drop_sprint operations.edit_task_comment
      operations.edit_work_session operations.link_repo_tasks operations.link_tasks operations.mark_task_seen
      operations.move_task operations.pause_task operations.place_task operations.plan_sprint
      operations.queue_issue_sync operations.reopen_task operations.reorder_task operations.save_task
      operations.save_task_rule operations.schedule_task operations.set_task_total operations.snooze_tasks
      operations.start_task operations.unlink_task operations.wake_task
      repos.sprint_queries repos.task_comment_queries repos.task_link_queries repos.task_queries
      repos.task_rule_queries repos.task_source_queries repos.time_report_queries repos.work_session_queries
    ]
  end
end
