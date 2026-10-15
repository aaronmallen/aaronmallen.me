# frozen_string_literal: true

module API
  module Operations
    class SummarizeAnalytics
      include Deps[
        event_queries: "analytics.repos.analytics_event_queries",
        feed_queries: "analytics.repos.feed_fetch_queries",
        hour_queries: "analytics.repos.analytics_hour_queries",
        page_queries: "analytics.repos.analytics_page_queries",
        post_queries: "posts.repos.post_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call(from:, to:, top:) = event_queries.memoizing { summarize(from, to, top) }

      private

      def change(views, from, to)
        before_to = from - 1
        before_from = before_to - (to - from).to_i
        before = rollup_queries.summary_between(from: before_from, to: before_to).fetch(:totals).fetch(:views)
        percent = Blog::Helpers::Figures.share(views - before, before) if before.positive?

        { from: before_from, to: before_to, views: before, percent: }
      end

      def ranked(found, read_throughs, **window)
        {
          paths: found.fetch(:paths).map { it.merge(read_throughs: read_throughs.fetch(it.fetch(:path), 0)) },
          referrers: found.fetch(:referrers),
          countries: found.fetch(:countries),
          sources: page_queries.sources_between(**window),
          devices: page_queries.devices_between(**window),
        }
      end

      def summarize(from, to, top)
        found = rollup_queries.summary_between(from:, to:)
        read_throughs = rollup_queries.read_throughs_between(from:, to:)
        views = found.fetch(:totals).fetch(:views)

        {
          totals: totals(found, read_throughs, from:, to:),
          days: found.fetch(:days),
          **ranked(found, read_throughs, from:, to:).transform_values { it.take(top) },
          change: change(views, from, to),
          feed: feed_queries.feed_subscribers_between(from:, to:),
          webmentions: webmentions(from, to, top),
          weekday_hours: hour_queries.weekday_hours,
        }
      end

      def totals(found, read_throughs, **window)
        reach = rollup_queries.reach_between(**window)

        found.fetch(:totals).merge(read_throughs: read_throughs.values.sum, reach:)
      end

      def webmention_post(post, counts) = { post_id: post.id, title: post.title, received: counts.fetch(post.id) }

      def webmentions(from, to, top)
        counts = webmention_queries.received_by_post(from:, to:)
        posts = post_queries.by_ids(counts.keys).map { webmention_post(it, counts) }

        {
          pending: webmention_queries.pending_count,
          received: webmention_queries.received_between(from:, to:),
          posts: posts.sort_by { [-it[:received], it[:title]] }.take(top),
        }
      end
    end
  end
end
