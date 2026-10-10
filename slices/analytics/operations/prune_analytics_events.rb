# frozen_string_literal: true

module Analytics
  module Operations
    class PruneAnalyticsEvents
      include Deps[
        event_mutations: "repos.analytics_event_mutations",
        event_queries: "repos.analytics_event_queries",
        feed_mutations: "repos.feed_fetch_mutations",
        rollup_queries: "repos.analytics_rollup_queries",
      ]

      def call
        feed_mutations.delete_hashes_before(cutoff)
        event_mutations.delete_before(Blog::TimeZone.day_start(rolled_up_through(cutoff)))
      end

      private

      def cutoff = event_queries.retention_start

      def rolled_up_through(before)
        oldest = event_queries.oldest_day
        return before if oldest.nil? || oldest >= before

        rolled = rollup_queries.days(from: oldest, to: before - 1).map(&:day)

        (oldest...before).find { !rolled.include?(it) } || before
      end
    end
  end
end
