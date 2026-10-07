# frozen_string_literal: true

module Tasks
  module Operations
    class UnlinkTask < Operation
      include Deps[task_mutations: "repos.task_mutations", task_queries: "repos.task_queries"]

      def call(id, other_id)
        step affected(task_mutations.unlink(id, other_id))

        task_queries.by_id(id)
      end
    end
  end
end
