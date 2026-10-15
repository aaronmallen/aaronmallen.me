# frozen_string_literal: true

module Tasks
  module Repos
    class TaskTimelineQueries < Blog::DB::Repo
      def entry(task_id, kind, source_id) = task_timeline.for_task(task_id).where(kind:, source_id:).one

      def for_task(task_id) = task_timeline.for_task(task_id).oldest_first.to_a
    end
  end
end
