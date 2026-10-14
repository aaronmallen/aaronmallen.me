# frozen_string_literal: true

module Record
  module Jobs
    class ReapSyncStates < Blog::ScheduledJob
      include Deps[
        reap_sync_states: "operations.reap_sync_states",
        record_sync_outcome: "operations.record_sync_outcome",
      ]

      def perform = reap_sync_states.call.tap { record(it) }

      private

      def record(result)
        case result
          in Success(_) | Failure(:not_configured | :no_repositories) then nil
          else record_sync_outcome.call(Blog::Types::SyncName["commits"], result)
        end
      end
    end
  end
end
