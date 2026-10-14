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
        record_crash(SYNC, :rollup_failed) { roll_up_analytics.call }
        record_crash(SYNC, :prune_failed) { prune_analytics_events.call }
        record_crash(SYNC, :readers_failed) { save_reader_counts.call }
        record_sync_outcome.call(SYNC, Success(nil))
      end
    end
  end
end
