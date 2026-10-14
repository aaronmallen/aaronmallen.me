# frozen_string_literal: true

module Tasks
  module Operations
    class SetTaskProject < Blog::Operation
      include Deps[task_mutations: "repos.task_mutations", task_queries: "repos.task_queries"]

      def call(task_id, project_id, from: nil)
        task = step found(task_queries.by_ids([task_id]).first)
        step held(task, project_id, from)

        step persist(task_id, project_id)
      end

      private

      def held(task, project_id, from)
        return Failure(:not_found) if from && task.project_id != from
        return Failure(:taken) if task.project_id == project_id

        Success(task)
      end

      def persist(id, project_id)
        Success(task_mutations.update(id, project_id:))
      rescue ROM::SQL::ForeignKeyConstraintError
        Failure(:missing)
      end
    end
  end
end
