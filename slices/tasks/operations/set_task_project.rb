# frozen_string_literal: true

module Tasks
  module Operations
    class SetTaskProject < Blog::Operation
      include Deps[
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
      ]

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

      def move(id, project_id)
        task_event_mutations.track(id, Time.now) do
          task_mutations.update(id, project_id:).tap { task_mutations.carry_tags([id], project_id) }
        end
      end

      def persist(id, project_id)
        Success(move(id, project_id))
      rescue ROM::SQL::ForeignKeyConstraintError
        Failure(:missing)
      end
    end
  end
end
