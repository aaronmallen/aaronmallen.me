# frozen_string_literal: true

module Tasks
  module Operations
    class MarkTaskSeen < Blog::Operation
      include Deps[task_repo: "repos.task_repo", task_source_repo: "repos.task_source_repo"]

      def call(id, at: Time.now)
        step find(id)
        task_source_repo.see(id, at)

        task_repo.by_id(id)
      end

      private

      def find(id)
        found(task_repo.by_id(id)).bind { it.source ? Success(it) : Failure(:unsourced) }
      end
    end
  end
end
