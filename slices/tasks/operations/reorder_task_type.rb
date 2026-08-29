# frozen_string_literal: true

module Tasks
  module Operations
    class ReorderTaskType < Blog::Operation
      OFFSETS = { Blog::Types::TaskMove["up"] => -1, Blog::Types::TaskMove["down"] => 1 }.freeze

      include Deps[task_type_repo: "repos.task_type_repo"]

      def call(id, direction)
        types = task_type_repo.all
        index = step locate(types, id)
        neighbour = step neighbour(types, index + OFFSETS.fetch(direction))

        task_type_repo.swap_positions(types[index], neighbour)
      end

      private

      def locate(types, id)
        index = types.index { it.id == id }

        index ? Success(index) : Failure(:not_found)
      end

      def neighbour(types, index)
        neighbour = types[index] unless index.negative?

        neighbour ? Success(neighbour) : Failure(:not_moved)
      end
    end
  end
end
