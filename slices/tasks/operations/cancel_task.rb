# frozen_string_literal: true

module Tasks
  module Operations
    class CancelTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo"]

      def call(id, at: Time.now)
        step find(id)

        task_repo.cancel(id, at:)
      end

      private

      def find(id)
        task = task_repo.by_id(id)
        return Failure(:not_found) unless task

        task.closed? ? Failure(:closed) : Success(task)
      end
    end
  end
end
