# frozen_string_literal: true

module Tasks
  module Repos
    class TaskContributorRepo < DB::Repo
      def add_missing(task_ids, contributors)
        rows = task_ids.product(contributors).map { |task_id, contributor| { task_id:, **contributor } }

        task_contributors.dataset.insert_conflict.multi_insert(rows) unless rows.empty?
      end

      def replace(task_id, contributors)
        transaction do
          task_contributors.for_task(task_id).delete
          task_contributors.dataset.multi_insert(contributors.map { { task_id:, agent: nil, model: nil, **it } })
        end
      end
    end
  end
end
