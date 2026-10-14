# frozen_string_literal: true

module Tasks
  module Operations
    class StageTask < Blog::Operation
      include Deps[task_mutations: "repos.task_mutations", task_queries: "repos.task_queries"]

      def call(id, stage)
        task = step find(id)

        transaction do
          task_mutations.lead(id) unless task.in_progress? || task.stage == stage
          task_mutations.update(id, stage: Blog::Types::TaskStage[stage])
        end
      end

      private

      def find(id)
        found(task_queries.by_id(id)).bind { it.closed? ? Failure(:closed) : Success(it) }
      end
    end
  end
end
