# frozen_string_literal: true

module Performance
  module Repos
    class RollupMutations < Blog::DB::Repo
      COUNT = Sequel.function(:count).*
      METRICS = Blog::Types::PerformancePageMetric.values
      QUERIES = {
        query_count: Sequel.function(:sum, :query_count),
        query_time: Sequel.function(:sum, :query_time),
      }.freeze

      def prune_before(time)
        [performance_jobs, performance_pages, performance_requests].each { it.where(occurred_at: ...time).delete }
      end

      def store(day)
        transaction do
          performance_rollups.where(day:).delete
          performance_rollups.insert(day:)
          roll(performance_rollup_requests, performance_requests, day, keys: %i[route verb], **QUERIES)
          roll(performance_rollup_jobs, performance_jobs, day, keys: %i[job], **QUERIES)
          METRICS.each { roll_page(day, it) }
        end
      end

      private

      def percentile(fraction, value) = Sequel.function(:percentile_cont, fraction).within_group(value)

      def roll(target, source, day, keys:, value: :duration, **extra)
        from, to = Blog::TimeZone.day_bounds(day, day)
        figures = { day: Sequel.cast(day, Date), count: COUNT, p50: percentile(0.5, value),
                    p95: percentile(0.95, value), **extra }
        rows = source.dataset.unordered.where(occurred_at: from...to).exclude(value => nil).group(*keys)

        target.dataset.insert([*keys, *figures.keys], rows.select(*keys, *figures.map { |name, sql| sql.as(name) }))
      end

      def roll_page(day, metric)
        cast = Sequel.cast(metric, :performance_page_metric)

        roll(performance_rollup_pages, performance_pages, day, keys: %i[route], value: metric.to_sym, metric: cast)
      end
    end
  end
end
