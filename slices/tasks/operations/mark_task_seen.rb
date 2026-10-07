# frozen_string_literal: true

module Tasks
  module Operations
    class MarkTaskSeen < Operation
      include Deps[task_queries: "repos.task_queries", task_source_mutations: "repos.task_source_mutations"]

      def call(id, at: Time.now)
        step find(id)
        task_source_mutations.see(id, at)

        task_queries.by_id(id)
      end

      private

      def find(id)
        found(task_queries.by_id(id)).bind { it.source ? Success(it) : Failure(:unsourced) }
      end
    end
  end
end
