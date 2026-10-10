# frozen_string_literal: true

module Tasks
  module Operations
    class PlaceTask < Blog::Operation
      include Deps[task_mutations: "repos.task_mutations", task_queries: "repos.task_queries"]

      def call(id, after_id)
        task = step find(id)
        step beside(task, after_id)
        step place(task, after_id)
      end

      private

      def beside(task, after_id)
        return Success(task) if after_id.nil?

        after = task_queries.by_id(after_id)
        return Failure(:after_not_found) unless after

        [after.list, after.sprint_id] == [task.list, task.sprint_id] ? Success(task) : Failure(:apart)
      end

      def find(id)
        found(task_queries.by_id(id))
      end

      def place(task, after_id) = task_mutations.place(task, after_id) ? Success(task.id) : Failure(:not_placed)
    end
  end
end
