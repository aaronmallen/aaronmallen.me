# frozen_string_literal: true

module Analytics
  module Operations
    class RollUpAnalytics < Operation
      include Deps[event_repo: "repos.analytics_event_repo", rollup_repo: "repos.analytics_rollup_repo"]

      def call
        days = pending
        rolled = days.map { rollup_repo.store(event_repo.summary_for(it)) }
        store_reach(days)
        rolled
      end

      private

      def oldest_pending = [rollup_repo.newest_day&.next_day, event_repo.oldest_day].compact.max

      def pending
        yesterday = Blog::TimeZone.today - 1

        ([oldest_pending || yesterday, yesterday].min..yesterday).to_a
      end

      def store_reach(days)
        complete = event_repo.complete_from(PruneAnalyticsEvents::RETENTION_DAYS)

        days.group_by { Date.new(it.year, it.month, 1) }.each do |month, in_month|
          next if month < complete

          rollup_repo.store_reach(month, event_repo.reach_by_path(from: month, to: in_month.last))
        end
      end
    end
  end
end
