# frozen_string_literal: true

module Tasks
  module Operations
    class CompleteTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo"]

      def call(id, at: Time.now)
        step find(id)

        task_repo.complete(id, at:)
      end

      private

      def find(id) = task_repo.by_id(id) ? Success(id) : Failure(:not_found)
    end
  end
end
