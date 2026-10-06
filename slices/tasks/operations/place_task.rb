# frozen_string_literal: true

module Tasks
  module Operations
    class PlaceTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo"]

      def call(id, after_id)
        task = step find(id)
        step beside(task, after_id)
        step place(task, after_id)
      end

      private

      def beside(task, after_id)
        return Success(task) if after_id.nil?

        after = task_repo.by_id(after_id)
        return Failure(:after_not_found) unless after

        [after.list, after.sprint_id] == [task.list, task.sprint_id] ? Success(task) : Failure(:apart)
      end

      def find(id)
        found(task_repo.by_id(id))
      end

      def place(task, after_id) = task_repo.place(task, after_id) ? Success(task.id) : Failure(:not_placed)
    end
  end
end
