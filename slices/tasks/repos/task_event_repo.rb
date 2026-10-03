# frozen_string_literal: true

module Tasks
  module Repos
    class TaskEventRepo < Blog::DB::Repo
      def track(task_ids, at, seen: true, &) = task_events.track(task_ids, at, seen:, &)
    end
  end
end
