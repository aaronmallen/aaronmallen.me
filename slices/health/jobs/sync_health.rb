# frozen_string_literal: true

module Health
  module Jobs
    class SyncHealth < Blog::ScheduledJob
      REREAD_DAYS = 2
      SYNC = Blog::Types::SyncName["health"]

      include Deps[
        record_sync_outcome: "record.operations.record_sync_outcome",
        sync_health: "operations.sync_health",
        sync_state_queries: "record.repos.sync_state_queries",
      ]

      def perform
        today = Blog::TimeZone.today

        record_crash(SYNC) { record_sync_outcome.call(SYNC, sync_health.call(first_day(today), today)) }
      end

      private

      def first_day(today)
        since = sync_state_queries.failure(SYNC)&.fetch(:since)

        [today, since && Blog::TimeZone.today(since)].compact.min - REREAD_DAYS
      end
    end
  end
end
