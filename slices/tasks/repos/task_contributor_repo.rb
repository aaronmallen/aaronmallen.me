# frozen_string_literal: true

module Tasks
  module Repos
    class TaskContributorRepo < Blog::DB::Repo
      def replace(task_id, contributors)
        transaction do
          task_contributors.for_task(task_id).delete
          task_contributors.dataset.multi_insert(contributors.map { { task_id:, agent: nil, model: nil, **it } })
        end
      end
    end
  end
end
