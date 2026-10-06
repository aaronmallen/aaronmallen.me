# frozen_string_literal: true

module Tasks
  module Relations
    class TaskContributors < Blog::DB::Relation
      schema :task_contributors, infer: true do
        associations do
          belongs_to :task
        end
      end

      def for_task(task_id) = where(task_id:)

      def in_order = order(self[:id].asc)
    end
  end
end
