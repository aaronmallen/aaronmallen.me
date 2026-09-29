# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTaskComment < Blog::Operation
      include Deps[task_comment_repo: "repos.task_comment_repo"]

      def call(task_id, id)
        step removed(task_comment_repo.delete_local(task_id, id))
      end

      private

      def removed(count) = count.positive? ? Success(count) : Failure(:not_found)
    end
  end
end
