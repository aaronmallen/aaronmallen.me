# frozen_string_literal: true

module Tasks
  module Operations
    class ReorderTask < Operation
      UP = Blog::Types::TaskMove["up"]

      include Deps[task_mutations: "repos.task_mutations", task_queries: "repos.task_queries"]

      def call(id, direction)
        task = step find(id)
        neighbour = step neighbour(task, direction)
        after = direction == UP ? task_queries.open_before(neighbour) : neighbour

        step place(task, after)
      end

      private

      def find(id)
        found(task_queries.by_id(id))
      end

      def neighbour(task, direction)
        return Failure(:not_moved) if task.closed?

        neighbour = direction == UP ? task_queries.open_before(task) : task_queries.open_after(task)

        neighbour ? Success(neighbour) : Failure(:not_moved)
      end

      def place(task, after) = task_mutations.place(task, after&.id) ? Success(task.id) : Failure(:not_moved)
    end
  end
end
