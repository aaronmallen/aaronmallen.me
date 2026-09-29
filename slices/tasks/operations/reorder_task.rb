# frozen_string_literal: true

module Tasks
  module Operations
    class ReorderTask < Blog::Operation
      UP = Blog::Types::TaskMove["up"]

      include Deps[task_repo: "repos.task_repo"]

      def call(id, direction)
        task = step find(id)
        neighbour = step neighbour(task, direction)

        task_repo.swap_positions(task, neighbour)
      end

      private

      def find(id)
        task = task_repo.by_id(id)

        task ? Success(task) : Failure(:not_found)
      end

      def neighbour(task, direction)
        return Failure(:not_moved) if task.closed?

        neighbour = direction == UP ? task_repo.open_before(task) : task_repo.open_after(task)

        neighbour ? Success(neighbour) : Failure(:not_moved)
      end
    end
  end
end
