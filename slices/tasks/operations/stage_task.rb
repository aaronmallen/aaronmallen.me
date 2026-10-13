# frozen_string_literal: true

module Tasks
  module Operations
    class StageTask < Blog::Operation
      include Deps[task_mutations: "repos.task_mutations", task_queries: "repos.task_queries"]

      def call(id, stage)
        step find(id)
        task_mutations.update(id, stage: Blog::Types::TaskStage[stage])
      end

      private

      def find(id)
        found(task_queries.by_id(id)).bind { it.closed? ? Failure(:closed) : Success(it) }
      end
    end
  end
end
