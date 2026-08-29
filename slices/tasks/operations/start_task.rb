# frozen_string_literal: true

module Tasks
  module Operations
    class StartTask < Blog::Operation
      include Deps[current_sprint: "operations.current_sprint", task_repo: "repos.task_repo"]

      def call(id)
        step find(id)
        sprint = step current_sprint.call

        task_repo.update(
          id,
          completed_at: nil,
          list: nil,
          sprint_id: sprint.id,
          status: Blog::Types::TaskStatus["in_progress"],
        )
      end

      private

      def find(id) = task_repo.by_id(id) ? Success(id) : Failure(:not_found)
    end
  end
end
