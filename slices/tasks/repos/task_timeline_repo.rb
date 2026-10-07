# frozen_string_literal: true

module Tasks
  module Repos
    class TaskTimelineRepo < DB::Repo
      def for_task(task_id) = task_timeline.for_task(task_id).oldest_first.to_a
    end
  end
end
