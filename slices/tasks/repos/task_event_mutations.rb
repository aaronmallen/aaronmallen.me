# frozen_string_literal: true

module Tasks
  module Repos
    class TaskEventMutations < Blog::DB::Repo
      RECURRED = Blog::Types::TaskTimelineKind["recurred"]

      root :task_events

      include Deps[diff: "operations.diff_task_history"]

      def recur(task_id, at) = task_events.command(:create).call(task_id:, kind: RECURRED, occurred_at: at)

      def track(task_ids, at, seen: true, &) = task_events.track(task_ids, at, diff:, seen:, &)
    end
  end
end
