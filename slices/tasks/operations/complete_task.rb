# frozen_string_literal: true

module Tasks
  module Operations
    class CompleteTask < Blog::Operation
      MINUTE = 60

      include Deps[
        contract: "contracts.worked_contract",
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
        work_session_repo: "repos.work_session_repo",
      ]

      def call(id, at: Time.now, worked: nil)
        step find(id)
        total = step reported(worked)

        task_event_repo.track(id, at) do
          work_session_repo.close(id, at)
          completed = task_repo.complete(id, at:)
          total ? task_repo.update(id, worked_seconds: total) : completed
        end
      end

      private

      def find(id) = task_repo.by_id(id) ? Success(id) : Failure(:not_found)

      def replaced(seconds, tracked)
        seconds unless seconds.nil? || (tracked && seconds / MINUTE == tracked / MINUTE)
      end

      def reported(worked)
        return Success(nil) unless worked

        validated(contract.call(hours: worked[:hours], minutes: worked[:minutes], tracked: worked[:tracked]))
          .fmap { |fields| replaced(Contracts::WorkedContract.seconds(fields), fields[:tracked]) }
      end
    end
  end
end
