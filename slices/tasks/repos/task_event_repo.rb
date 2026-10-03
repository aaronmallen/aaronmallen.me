# frozen_string_literal: true

module Tasks
  module Repos
    class TaskEventRepo < Blog::DB::Repo
      def track(task_ids, at, &) = task_events.track(task_ids, at, &)
    end
  end
end
