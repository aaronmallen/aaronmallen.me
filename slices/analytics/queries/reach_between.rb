# frozen_string_literal: true

module Analytics
  module Queries
    class ReachBetween
      include Deps[event_repo: "repos.analytics_event_repo", rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:, path: nil)
        complete = event_repo.complete_from(Operations::PruneAnalyticsEvents::RETENTION_DAYS)
        counts = months(from, to).map { reach(it, path, complete) }

        counts.sum unless counts.include?(nil)
      end

      private

      def months(from, to) = (from..to).slice_when { |day, after| day.month != after.month }.map { it.first..it.last }

      def reach(days, path, complete)
        return event_repo.reach_between(from: days.first, to: days.last, path:) if days.first >= complete
        return unless whole_month?(days)

        rolled = rollup_repo.reach_in(days.first)
        rolled.fetch(path, 0) unless rolled.empty?
      end

      def whole_month?(days) = days.first.mday == 1 && days.last.next_day.mday == 1
    end
  end
end
