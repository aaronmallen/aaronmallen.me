# frozen_string_literal: true

module Analytics
  module Queries
    class UnrolledSummaries
      include Deps[event_repo: "repos.analytics_event_repo", rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:)
        oldest = event_repo.oldest_day
        return Blog::Constants::EMPTY_ARRAY unless oldest

        days = [from, oldest].max..[to, Blog::TimeZone.today].min
        rolled = rollup_repo.days(from: days.first, to: days.last).map(&:day)

        days.reject { rolled.include?(it) }.map { event_repo.summary_for(it) }
      end
    end
  end
end
