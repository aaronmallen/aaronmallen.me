# frozen_string_literal: true

module Performance
  module Repos
    class TimingQueries < Blog::DB::Repo
      COUNT = Sequel.function(:count).*
      DAY = Sequel.function(:timezone, Blog::TimeZone::NAME, :occurred_at).cast(:date)
      EMPTY_DAY = { count: 0, p50: nil, p95: nil }.freeze
      SLOWEST_LIMIT = 25

      def route_days_between(route:, verb:, from:, to:)
        daily(within(performance_requests, from, to).where(route:, verb:), from, to)
      end

      def slowest_requests(route:, verb:, from:, to:)
        within(performance_requests, from, to).where(route:, verb:)
                                              .select(:status, :duration, :query_count, :query_time, :occurred_at)
                                              .reverse(:duration).limit(SLOWEST_LIMIT).to_a
      end

      private

      def daily(dataset, from, to)
        found = dataset.group(DAY).select(
          DAY.as(:day), COUNT.as(:count), percentile(0.5, :duration).as(:p50), percentile(0.95, :duration).as(:p95),
        ).to_h { [it.delete(:day), it] }

        (from..to).map { { day: it, **found.fetch(it, EMPTY_DAY) } }
      end

      def percentile(fraction, value) = Sequel.function(:percentile_cont, fraction).within_group(value)

      def within(relation, from, to)
        relation.dataset.unordered.where(occurred_at: Range.new(*Blog::TimeZone.day_bounds(from, to), true))
      end
    end
  end
end
