# frozen_string_literal: true

module Tasks
  module Repos
    class TaskEventMutations < DB::Repo
      root :task_events

      include Deps[diff: "operations.diff_task_history"]

      def track(task_ids, at, seen: true, &) = task_events.track(task_ids, at, diff:, seen:, &)
    end
  end
end
