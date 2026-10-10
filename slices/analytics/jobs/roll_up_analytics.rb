# frozen_string_literal: true

module Analytics
  module Jobs
    class RollUpAnalytics < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["analytics_rollup"]

      include Deps[
        prune_analytics_events: "operations.prune_analytics_events",
        record_sync_outcome: "record.operations.record_sync_outcome",
        roll_up_analytics: "operations.roll_up_analytics",
        save_reader_counts: "operations.save_reader_counts",
      ]

      def perform
        attempt(:rollup_failed) { roll_up_analytics.call }
        attempt(:prune_failed) { prune_analytics_events.call }
        attempt(:readers_failed) { save_reader_counts.call }
        record_sync_outcome.call(SYNC, Success(nil))
      end

      private

      def attempt(reason)
        yield
      rescue StandardError => e
        record_and_raise(SYNC, Failure([reason, e.message]), e)
      end
    end
  end
end
