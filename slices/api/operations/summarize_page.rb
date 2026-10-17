# frozen_string_literal: true

module API
  module Operations
    class SummarizePage
      include Deps[
        event_queries: "analytics.repos.analytics_event_queries",
        page_queries: "analytics.repos.analytics_page_queries",
        post_reader_queries: "analytics.repos.post_reader_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
      ]

      def call(path:, from:, to:, top:, post: nil)
        event_queries.memoizing { summarize({ path:, from:, to: }, top, post) }
      end

      private

      def published(post, path)
        {
          first_days: page_queries.first_days(path),
          unique_readers: post_reader_queries.unique_readers([post]).fetch(post.id),
        }
      end

      def ranked(found, window)
        {
          referrers: found.fetch(:referrers),
          countries: found.fetch(:countries),
          sources: page_queries.sources_between(**window),
          devices: page_queries.devices_between(**window),
          clicks: page_queries.clicks_between(**window),
        }
      end

      def summarize(window, top, post)
        found = page_queries.page_between(**window)

        {
          totals: totals(found, window),
          days: found.fetch(:days),
          **ranked(found, window).transform_values { it.take(top) },
          scroll: page_queries.scroll_depths_between(**window),
          **(post ? published(post, window.fetch(:path)) : {}),
        }
      end

      def totals(found, window)
        read_throughs = rollup_queries.read_throughs_between(**window.slice(:from, :to)).fetch(window.fetch(:path), 0)
        reach = rollup_queries.reach_between(**window)

        found.fetch(:totals).merge(read_throughs:, bounces: found.fetch(:bounces), reach:)
      end
    end
  end
end
