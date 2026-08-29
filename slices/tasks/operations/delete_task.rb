# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo"]

      def call(id)
        step deleted(task_repo.delete(id))
      end

      private

      def deleted(task) = task ? Success(task) : Failure(:not_found)
    end
  end
end
