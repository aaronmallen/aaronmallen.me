# frozen_string_literal: true

module Analytics
  module Queries
    class ReadSpreadBetween
      FLOORS = [0, 1, 10, 30, 60, 120, 300, 600].freeze

      include Deps[event_repo: "repos.analytics_event_repo"]

      def call(from:, to:, path: nil)
        return unless from >= Blog::TimeZone.day_start(kept_from)

        views = event_repo.views_by_read_floor(from:, to:, path:, floors: FLOORS)
        median = event_repo.median_read_seconds(from:, to:, path:)

        { median: median&.round(1), buckets: buckets(views) }
      end

      private

      def buckets(views)
        ceilings = FLOORS.drop(1).map(&:pred) << Operations::RecordVisit::MAX_READ_SECONDS

        FLOORS.zip(ceilings).map { |floor, ceiling| { from: floor, to: ceiling, views: views.fetch(floor, 0) } }
      end

      def kept_from = event_repo.complete_from(Operations::PruneAnalyticsEvents::RETENTION_DAYS)
    end
  end
end
