# frozen_string_literal: true

module Tasks
  module Operations
    class ResumeTaskSeries < Blog::Operation
      include Deps[
        recur_task: "operations.recur_task",
        task_series_mutations: "repos.task_series_mutations",
        task_series_queries: "repos.task_series_queries",
      ]

      def call(id, at: Time.now)
        transaction do
          step affected(task_series_mutations.switch(id, false, at))

          step recur_task.call(task_series_queries.by_id(id).task_id, at:)
        end
      end
    end
  end
end
