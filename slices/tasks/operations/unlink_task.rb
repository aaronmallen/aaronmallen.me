# frozen_string_literal: true

module Tasks
  module Operations
    class UnlinkTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo"]

      def call(id, other_id)
        step removed(task_repo.unlink(id, other_id))

        task_repo.by_id(id)
      end

      private

      def removed(count) = count.positive? ? Success(count) : Failure(:not_found)
    end
  end
end
