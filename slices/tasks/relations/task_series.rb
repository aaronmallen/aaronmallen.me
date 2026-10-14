# frozen_string_literal: true

module Tasks
  module Relations
    class TaskSeries < Blog::DB::Relation
      CADENCE = %i[cadence every weekday week day month starts_on].freeze

      schema :task_series, infer: true do
        associations do
          belongs_to :task
        end
      end

      def set(task_id, fields, at)
        row = CADENCE.to_h { [it, nil] }.merge(fields, task_id:, created_at: at, updated_at: at)

        dataset.insert_conflict(target: :task_id, update: excluded([*CADENCE, :updated_at])).insert(row)
      end
    end
  end
end
