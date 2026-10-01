# frozen_string_literal: true

module Analytics
  module Queries
    class NavigationBetween
      include Deps[event_repo: "repos.analytics_event_repo"]

      def call(from:, to:, path: nil)
        return unless from >= Blog::TimeZone.day_start(kept_from)

        path ? { internal_referrers: internal_referrers(from:, to:, path:) } : ends(from:, to:)
      end

      private

      def ends(from:, to:)
        {
          entry_pages: event_repo.visit_ends_between(from:, to:, direction: :asc),
          exit_pages: event_repo.visit_ends_between(from:, to:, direction: :desc),
        }
      end

      def internal_referrers(from:, to:, path:)
        rows = event_repo.internal_referrers_between(from:, to:, path:).map(&:to_h)

        rows.sort_by { [-it.fetch(:visitors), -it.fetch(:views), it.fetch(:path)] }
      end

      def kept_from = event_repo.complete_from(Operations::PruneAnalyticsEvents::RETENTION_DAYS)
    end
  end
end
