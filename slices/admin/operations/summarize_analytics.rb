# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeAnalytics
      TOP_ROWS = 10

      include Deps[
        page_queries: "analytics.repos.analytics_page_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
        summarize: "api.operations.summarize_analytics",
      ]

      def call(range:)
        to = Blog::TimeZone.today
        from = to - (range - 1)
        found = summarize.call(from:, to:, top: TOP_ROWS)
        totals = found.fetch(:totals)

        {
          **found.slice(:countries, :feed, :referrers, :webmentions, :weekday_hours),
          change: found.fetch(:change).fetch(:percent),
          paths: with_posts(found.fetch(:paths)),
          range:,
          scroll: page_queries.scroll_depths_between(from:, to:),
          series: found.fetch(:days),
          totals: totals.slice(:views, :visitors, :read_seconds),
          **stats(totals),
        }
      end

      private

      def stats(totals)
        views = totals.fetch(:views)

        {
          per_visit: Blog::Helpers::Figures.rate(views, totals.fetch(:visitors)),
          read_time: Blog::Helpers::Figures.average(totals.fetch(:read_seconds), views),
        }
      end

      def with_posts(paths)
        ids = rollup_queries.post_ids_by_path(paths.map { it[:path] })

        paths.map { it.merge(post_id: ids[it[:path]]) }
      end
    end
  end
end
