# frozen_string_literal: true

module Analytics
  module Jobs
    class RollUpAnalytics < Blog::Job
      include Deps[
        prune_analytics_events: "operations.prune_analytics_events",
        record_rollup_sync_outcome: "record.operations.record_rollup_sync_outcome",
        roll_up_analytics: "operations.roll_up_analytics",
      ]

      sidekiq_options retry: false

      def perform
        attempt(:rollup_failed) { roll_up_analytics.call }
        attempt(:prune_failed) { prune_analytics_events.call }
        record_rollup_sync_outcome.call(Success(nil))
      end

      private

      def attempt(reason)
        yield
      rescue StandardError => e
        record_rollup_sync_outcome.call(Failure([reason, e.message]))
        raise
      end
    end
  end
end
