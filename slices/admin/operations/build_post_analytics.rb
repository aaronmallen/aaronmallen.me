# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostAnalytics
      TOP_ROWS = 10

      include Deps[
        page_queries: "analytics.repos.analytics_page_queries",
        post_reader_queries: "analytics.repos.post_reader_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
      ]

      def call(post:, range:)
        to = Blog::TimeZone.today
        window = { from: to - (range - 1), to:, path: "#{Blog::Constants::WRITING_PATH}/#{post.slug}" }
        page = page_queries.page_between(**window)

        {
          post:,
          range:,
          **counts(page, window),
          **breakdowns(page, window),
          first_days: page_queries.first_days(window.fetch(:path)),
          unique_readers: post_reader_queries.unique_readers([post]).fetch(post.id),
        }
      end

      private

      def breakdowns(page, window)
        {
          clicks: page_queries.clicks_between(**window).take(TOP_ROWS),
          countries: page.fetch(:countries).take(TOP_ROWS),
          devices: page_queries.devices_between(**window).take(TOP_ROWS),
          referrers: page.fetch(:referrers).take(TOP_ROWS),
          scroll: page_queries.scroll_depths_between(**window),
          sources: page_queries.sources_between(**window).take(TOP_ROWS),
        }
      end

      def counts(page, window)
        path = window.fetch(:path)
        to = window.fetch(:to)

        {
          **page.fetch(:totals).slice(:views, :visitors),
          bounces: page.fetch(:bounces),
          read_throughs: rollup_queries.read_throughs_between(from: window.fetch(:from), to:).fetch(path, 0),
          readers: rollup_queries.reach_between(from: Date.new(to.year, to.month), to:, path:),
        }
      end
    end
  end
end
