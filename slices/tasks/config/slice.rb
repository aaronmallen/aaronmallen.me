# frozen_string_literal: true

module Tasks
  class Slice < Hanami::Slice
    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[repos.project_queries], from: :projects

    import keys: %w[operations.record_sync_outcome], from: :record

    export %w[
      operations.act_on_tasks operations.add_task_comment operations.cancel_task operations.capture_task
      operations.close_decision_task operations.complete_task operations.current_sprint operations.delete_task
      operations.delete_task_comment operations.delete_task_rule operations.delete_work_session operations.drop_sprint
      operations.edit_task_comment operations.edit_work_session operations.link_repo_tasks operations.link_tasks
      operations.mark_task_seen operations.move_task operations.next_cadence_date operations.open_decision_task
      operations.pause_task operations.pause_task_series operations.place_task operations.plan_sprint
      operations.queue_issue_sync operations.rename_decision_task operations.reopen_decision_task
      operations.reopen_task operations.reorder_task operations.resume_task_series operations.save_task
      operations.save_task_rule operations.schedule_task operations.set_task_column operations.set_task_project
      operations.set_task_total operations.set_tasks_column operations.snooze_tasks operations.stage_task
      operations.start_task operations.unlink_task operations.wake_task
      repos.sprint_queries repos.task_comment_queries repos.task_queries repos.task_rule_queries
      repos.task_series_queries repos.task_source_queries repos.time_report_queries
    ]
  end
end
