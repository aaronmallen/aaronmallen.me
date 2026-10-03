# frozen_string_literal: true

module Tasks
  module Relations
    class TaskTimeline < Blog::DB::Relation
      schema :task_timeline, infer: true

      def for_task(task_id) = where(task_id:)

      def oldest_first = order(self[:occurred_at].asc, self[:kind].asc, self[:source_id].asc)
    end
  end
end
