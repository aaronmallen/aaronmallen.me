# frozen_string_literal: true

module Tasks
  module Operations
    class CancelTask < Blog::Operation
      include Deps[
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(id, at: Time.now)
        step find(id)

        task_event_mutations.track(id, at) do
          work_session_mutations.close(id, at)
          task_mutations.cancel(id, at:)
        end
      end

      private

      def find(id)
        found(task_queries.by_id(id)).bind { it.closed? ? Failure(:closed) : Success(it) }
      end
    end
  end
end
