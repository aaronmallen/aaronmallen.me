# frozen_string_literal: true

module Tasks
  module Operations
    class ReorderTask < Blog::Operation
      OFFSETS = { Blog::Types::TaskMove["up"] => -1, Blog::Types::TaskMove["down"] => 1 }.freeze

      include Deps[task_repo: "repos.task_repo"]

      def call(id, direction)
        task = step find(id)
        neighbour = step neighbour(task, OFFSETS.fetch(direction))

        task_repo.swap_positions(task, neighbour)
      end

      private

      def beside(task) = task.listed? ? task_repo.open_in_list(task.list) : task_repo.open_in_sprint(task.sprint_id)

      def find(id)
        task = task_repo.by_id(id)

        task ? Success(task) : Failure(:not_found)
      end

      def neighbour(task, offset)
        return Failure(:not_moved) if task.closed?

        beside = beside(task)
        index = beside.index { it.id == task.id } + offset
        neighbour = beside[index] unless index.negative?

        neighbour ? Success(neighbour) : Failure(:not_moved)
      end
    end
  end
end
