# frozen_string_literal: true

module Tasks
  module Operations
    class CompleteTask < Blog::Operation
      include Deps[
        contract: "contracts.worked_contract",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(id, at: Time.now, worked: nil)
        step find(id)
        total = step reported(worked)

        task_event_mutations.track(id, at) do
          work_session_mutations.close(id, at)
          completed = task_mutations.complete(id, at:)
          total ? task_mutations.update(id, worked_seconds: total) : completed
        end
      end

      private

      def find(id)
        found(task_queries.by_id(id)).bind { it.closed? ? Failure(:closed) : Success(it) }
      end

      def replaced(seconds, tracked)
        unless seconds.nil? || (tracked && seconds / Blog::Helpers::Figures::MINUTE == tracked / Blog::Helpers::Figures::MINUTE)
          seconds
        end
      end

      def reported(worked)
        return Success(nil) unless worked

        validated(contract.call(hours: worked[:hours], minutes: worked[:minutes], tracked: worked[:tracked]))
          .fmap { |fields| replaced(Contracts::WorkedContract.seconds(fields), fields[:tracked]) }
      end
    end
  end
end
