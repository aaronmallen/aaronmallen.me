# frozen_string_literal: true

module Analytics
  module Queries
    class HourlyBetween
      include Deps[event_repo: "repos.analytics_event_repo"]

      def call(from:, to:, path: nil)
        return unless from >= Blog::TimeZone.day_start(kept_from)

        found = { hours: event_repo.hours_between(from:, to:, path:).map(&:to_h) }
        found[:totals] = event_repo.totals_between(from:, to:, path:).to_h
        path ? found : found.merge(paths: ranked(event_repo.paths_between(from:, to:)))
      end

      private

      def kept_from = event_repo.complete_from(Operations::PruneAnalyticsEvents::RETENTION_DAYS)

      def ranked(rows) = rows.map(&:to_h).sort_by { [-it.fetch(:views), it.fetch(:path)] }
    end
  end
end
