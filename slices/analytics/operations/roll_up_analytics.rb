# frozen_string_literal: true

module Analytics
  module Operations
    class RollUpAnalytics < Blog::Operation
      include Deps[event_repo: "repos.analytics_event_repo", rollup_repo: "repos.analytics_rollup_repo"]

      def call
        pending.map { rollup_repo.store(event_repo.summary_for(it)) }
      end

      private

      def oldest_pending = [rollup_repo.newest_day&.next_day, event_repo.oldest_day].compact.max

      def pending
        yesterday = Blog::TimeZone.today - 1

        ([oldest_pending || yesterday, yesterday].min..yesterday).to_a
      end
    end
  end
end
