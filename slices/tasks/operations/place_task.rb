# frozen_string_literal: true

module Tasks
  module Operations
    class PlaceTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo"]

      def call(id, after_id)
        task = step find(id)
        step place(task, after_id)
      end

      private

      def find(id)
        task = task_repo.by_id(id)

        task ? Success(task) : Failure(:not_found)
      end

      def place(task, after_id) = task_repo.place(task, after_id) ? Success(task.id) : Failure(:not_placed)
    end
  end
end
