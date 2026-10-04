# frozen_string_literal: true

module Analytics
  module Operations
    class PruneAnalyticsEvents < Blog::Operation
      RETENTION_DAYS = 90

      include Deps[
        event_repo: "repos.analytics_event_repo",
        feed_repo: "repos.feed_fetch_repo",
        rollup_repo: "repos.analytics_rollup_repo",
      ]

      def call
        feed_repo.delete_hashes_before(cutoff)
        event_repo.delete_before(Blog::TimeZone.day_start(rolled_up_through(cutoff)))
      end

      private

      def cutoff = Blog::TimeZone.today - (RETENTION_DAYS - 1)

      def rolled_up_through(before)
        oldest = event_repo.oldest_day
        return before if oldest.nil? || oldest >= before

        rolled = rollup_repo.days(from: oldest, to: before - 1).map(&:day)

        (oldest...before).find { !rolled.include?(it) } || before
      end
    end
  end
end
