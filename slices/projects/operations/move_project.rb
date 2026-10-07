# frozen_string_literal: true

module Projects
  module Operations
    class MoveProject < Operation
      include Deps[project_repo: "repos.project_repo"]

      OFFSETS = { Blog::Types::ProjectMove["up"] => -1, Blog::Types::ProjectMove["down"] => 1 }.freeze

      def call(id, direction)
        live = project_repo.live
        index = step locate(live, id)
        neighbour = step neighbour(live, index + OFFSETS.fetch(direction))

        project_repo.swap_positions(live[index], neighbour)
      end

      private

      def locate(live, id)
        found(live.index { it.id == id })
      end

      def neighbour(live, index)
        neighbour = live[index] unless index.negative?

        neighbour ? Success(neighbour) : Failure(:not_moved)
      end
    end
  end
end
