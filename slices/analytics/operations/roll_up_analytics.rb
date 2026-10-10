# frozen_string_literal: true

module Analytics
  module Operations
    class RollUpAnalytics
      include Deps[
        event_queries: "repos.analytics_event_queries",
        rollup_mutations: "repos.analytics_rollup_mutations",
        rollup_queries: "repos.analytics_rollup_queries",
      ]

      def call
        days = pending
        rolled = days.map { rollup_mutations.store(event_queries.summary_for(it)) }
        store_reach(days)
        rolled
      end

      private

      def oldest_pending = [rollup_queries.newest_day&.next_day, event_queries.oldest_day].compact.max

      def pending
        yesterday = Blog::TimeZone.today - 1

        ([oldest_pending || yesterday, yesterday].min..yesterday).to_a
      end

      def store_reach(days)
        complete = event_queries.complete_from

        days.group_by { Date.new(it.year, it.month, 1) }.each do |month, in_month|
          next if month < complete

          rollup_mutations.store_reach(month, event_queries.reach_by_path(from: month, to: in_month.last))
        end
      end
    end
  end
end
