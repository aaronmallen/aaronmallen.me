# frozen_string_literal: true

module Tasks
  module Relations
    class TaskLinks < Blog::DB::Relation
      schema :task_links, infer: true do
        associations do
          belongs_to :tasks, as: :from_task, foreign_key: :from_task_id
          belongs_to :tasks, as: :to_task, foreign_key: :to_task_id
        end
      end

      def between(one, two)
        ends = [one, two].minmax

        where(
          Sequel.function(:least, :from_task_id, :to_task_id) => ends.first,
          Sequel.function(:greatest, :from_task_id, :to_task_id) => ends.last,
        )
      end

      def partner_ids(id)
        where(from_task_id: id).select(:to_task_id).union(where(to_task_id: id).select(:from_task_id))
      end
    end
  end
end
