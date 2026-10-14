# frozen_string_literal: true

module Performance
  module Repos
    class TimingQueries < Blog::DB::Repo
      COUNT = Sequel.function(:count).*
      DAY = Sequel.function(:timezone, Blog::TimeZone::NAME, :occurred_at).cast(:date)
      EMPTY_DAY = { count: 0, p50: nil, p95: nil }.freeze
      PAGE_METRICS = %i[load lcp].freeze
      PAGE_VERB = "GET"
      SLOWEST_LIMIT = 25

      def days_between(from:, to:) = daily(within(performance_requests, from, to), from, to)

      def jobs_between(from:, to:) = ranked(performance_jobs, from, to, :job)

      def pages_between(from:, to:)
        figures = PAGE_METRICS.flat_map do |metric|
          [percentile(0.5, metric).as(:"#{metric}_p50"), percentile(0.95, metric).as(:"#{metric}_p95")]
        end

        within(performance_pages, from, to).group(:route).select(:route, *figures).to_h { [it.delete(:route), it] }
      end

      def route_days_between(route:, verb:, from:, to:)
        daily(within(performance_requests, from, to).where(route:, verb:), from, to)
      end

      def routes_between(from:, to:) = ranked(performance_requests, from, to, :route, :verb)

      def slowest_requests(route:, verb:, from:, to:)
        within(performance_requests, from, to).where(route:, verb:)
                                              .select(:status, :duration, :query_count, :query_time, :occurred_at)
                                              .reverse(:duration).limit(SLOWEST_LIMIT).to_a
      end

      def summary_between(from:, to:)
        pages = pages_between(from:, to:)
        routes = routes_between(from:, to:).map do |route|
          route.merge(browser: (pages[route[:route]] if route[:verb] == PAGE_VERB))
        end

        { jobs: jobs_between(from:, to:), routes: }
      end

      private

      def average(column) = Sequel.cast(Sequel.function(:avg, column), Float)

      def daily(dataset, from, to)
        found = dataset.group(DAY).select(
          DAY.as(:day), COUNT.as(:count), percentile(0.5, :duration).as(:p50), percentile(0.95, :duration).as(:p95),
        ).to_h { [it.delete(:day), it] }

        (from..to).map { { day: it, **found.fetch(it, EMPTY_DAY) } }
      end

      def percentile(fraction, value) = Sequel.function(:percentile_cont, fraction).within_group(value)

      def ranked(relation, from, to, *keys)
        within(relation, from, to).group(*keys).select(
          *keys, COUNT.as(:count), percentile(0.5, :duration).as(:p50), percentile(0.95, :duration).as(:p95),
          average(:query_count).as(:query_count), average(:query_time).as(:query_time),
        ).order(Sequel.desc(:p95), *keys).to_a
      end

      def within(relation, from, to)
        relation.dataset.unordered.where(occurred_at: Range.new(*Blog::TimeZone.day_bounds(from, to), true))
      end
    end
  end
end
