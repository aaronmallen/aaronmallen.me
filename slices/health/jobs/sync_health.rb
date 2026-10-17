# frozen_string_literal: true

module Health
  module Jobs
    class SyncHealth < Blog::ScheduledJob
      REREAD_DAYS = 2
      SYNC = Blog::Types::SyncName["health"]

      include Record::SyncBookkeeping
      include Deps["operations.sync_health", sync_state_queries: "record.repos.sync_state_queries"]

      def perform = record_sync(SYNC) { Blog::TimeZone.today.then { sync_health.call(first_day(it), it) } }

      private

      def first_day(today)
        since = sync_state_queries.failure(SYNC)&.fetch(:since)

        [today, since && Blog::TimeZone.today(since)].compact.min - REREAD_DAYS
      end
    end
  end
end
