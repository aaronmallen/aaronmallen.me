# frozen_string_literal: true

module Tasks
  module Operations
    class RemoveTaskType < Blog::Operation
      include Deps[task_type_repo: "repos.task_type_repo"]

      def call(id)
        type = step find(id)
        step unused(type)

        task_type_repo.delete(type.id)
      end

      private

      def find(id)
        type = task_type_repo.by_id(id)

        type ? Success(type) : Failure(:not_found)
      end

      def unused(type)
        held = task_type_repo.task_counts.fetch(type.id, 0)

        held.zero? ? Success(type) : Failure([:in_use, held])
      end
    end
  end
end
