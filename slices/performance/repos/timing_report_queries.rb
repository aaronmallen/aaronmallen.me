# frozen_string_literal: true

module Performance
  module Repos
    class TimingReportQueries < Blog::DB::Repo
      COUNT = Sequel.function(:count).*
      DAY = Blog::DB::Relation.site_day(:occurred_at)
      EMPTY_DAY = { count: 0, p50: nil, p95: nil }.freeze
      METRICS = Blog::Types::PerformancePageMetric.values.map(&:to_sym).freeze
      QUERIES = %i[query_count query_time].freeze
      TOTAL = Sequel.function(:sum, :count)

      def days(range)
        rolled = performance_rollup_requests.dataset
        days = daily(rolled, performance_requests, range, keys: %i[route verb], extra: [], by_day: true)
        found = combined(days, %i[day], []).to_a.to_h { [it.fetch(:day), rounded(it.except(:day))] }

        range.map { { day: it, **found.fetch(it, EMPTY_DAY) } }
      end

      def jobs(range, top = nil) = ranked(performance_rollup_jobs.dataset, performance_jobs, range, top, keys: %i[job])

      def pages(range, top = nil)
        found = METRICS.to_h { |metric| [metric, page_figures(range, metric)] }

        routes = found.fetch(:load).keys

        routes.first(top || routes.size).map { |route| { route:, **found.transform_values { it[route] } } }
      end

      def routes(range, top = nil)
        ranked(performance_rollup_requests.dataset, performance_requests, range, top, keys: %i[route verb])
      end

      private

      def combined(days, keys, extra)
        days.unordered.group(*keys).order(Sequel.desc(:p95), *keys).select(
          *keys, TOTAL.cast(Integer).as(:count), weighted(:p50), weighted(:p95),
          *extra.map { Sequel.function(:sum, it).cast(it == :query_count ? Integer : Float).as(it) },
        )
      end

      def daily(rolled, source, range, keys:, value: :duration, extra: QUERIES, by_day: false)
        figures = [
          *keys, *(DAY.as(:day) if by_day), COUNT.as(:count), Blog::DB::Relation.percentile(0.5, value).as(:p50),
          Blog::DB::Relation.percentile(0.95, value).as(:p95), *extra.map { Sequel.function(:sum, it).as(it) },
        ]

        rolled.unordered.where(day: range).select(*keys, *(:day if by_day), :count, :p50, :p95, *extra)
              .union(raw(source, range, value).group(*keys, DAY).select(*figures), all: true)
      end

      def page_figures(range, metric)
        rolled = performance_rollup_pages.dataset.where(metric: metric.to_s)
        days = daily(rolled, performance_pages, range, keys: %i[route], value: metric, extra: [])

        combined(days, %i[route], []).to_a.to_h { [it.fetch(:route), rounded(it.except(:route))] }
      end

      def ranked(rolled, source, range, top, keys:)
        combined(daily(rolled, source, range, keys:), keys, QUERIES).limit(top).to_a.map { rounded(it) }
      end

      def raw(source, range, value)
        first = [range.first, performance_rollups.dataset.max(:day)&.next_day].compact.max
        from, to = Blog::TimeZone.day_bounds(first, range.last)
        rolled_days = performance_rollups.dataset.where(day: range).select(:day)

        source.dataset.unordered.where(occurred_at: from...to).exclude(value => nil).exclude(DAY => rolled_days)
      end

      def rounded(row) = row.transform_values { it.is_a?(Float) ? it.round(1) : it }

      def weighted(column) = (Sequel.function(:sum, Sequel[column] * :count) / TOTAL).as(column)
    end
  end
end
