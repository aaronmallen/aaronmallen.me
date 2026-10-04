# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostAnalytics
      TOP_ROWS = 10

      include Deps[
        clicks_between: "analytics.queries.clicks_between",
        devices_between: "analytics.queries.devices_between",
        first_days: "analytics.queries.first_days",
        page_between: "analytics.queries.page_between",
        reach_between: "analytics.queries.reach_between",
        read_throughs_between: "analytics.queries.read_throughs_between",
        readers_by_path: "analytics.queries.readers_by_path",
        scroll_depths_between: "analytics.queries.scroll_depths_between",
        sources_between: "analytics.queries.sources_between",
      ]

      def call(post:, range:)
        to = Blog::TimeZone.today
        window = { from: to - (range - 1), to:, path: "#{Blog::Site::WRITING}/#{post.slug}" }
        page = page_between.call(**window)

        {
          post:,
          range:,
          **counts(page, window),
          **breakdowns(page, window),
          first_days: first_days.call(window.fetch(:path)),
          unique_readers: unique_readers(post),
        }
      end

      private

      def breakdowns(page, window)
        {
          clicks: clicks_between.call(**window).take(TOP_ROWS),
          countries: page.fetch(:countries).take(TOP_ROWS),
          devices: devices_between.call(**window).take(TOP_ROWS),
          referrers: page.fetch(:referrers).take(TOP_ROWS),
          scroll: scroll_depths_between.call(**window),
          sources: sources_between.call(**window).take(TOP_ROWS),
        }
      end

      def counts(page, window)
        path = window.fetch(:path)
        to = window.fetch(:to)

        {
          **page.fetch(:totals).slice(:views, :visitors),
          bounces: page.fetch(:bounces),
          read_throughs: read_throughs_between.call(from: window.fetch(:from), to:).fetch(path, 0),
          readers: reach_between.call(from: Date.new(to.year, to.month), to:, path:),
        }
      end

      def unique_readers(post) = UniqueReaders.of(post, readers_by_path.call([UniqueReaders.path(post)]))
    end
  end
end
