# frozen_string_literal: true

module Tasks
  class Slice < Hanami::Slice
    export %w[
      operations.capture_task operations.complete_task operations.current_sprint operations.delete_task
      operations.drop_sprint operations.link_tasks operations.move_task operations.plan_sprint
      operations.remove_task_type operations.reopen_task operations.reorder_task operations.reorder_task_type
      operations.save_task operations.save_task_type operations.schedule_task operations.start_task
      operations.unlink_task
      queries.find_tasks queries.finished_task_counts queries.link_targets queries.list_finished_tasks
      queries.list_tasks queries.open_tasks queries.open_tasks_in_list queries.search_tasks queries.sprints_after
      queries.sprints_between queries.task_by_id queries.task_counts_by_type queries.task_types
      queries.tasks_in_sprint
    ]
  end
end
