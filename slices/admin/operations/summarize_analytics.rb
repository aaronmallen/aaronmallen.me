# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeAnalytics
      RANKED = %i[countries paths referrers].freeze
      TOP_ROWS = 10

      include Deps[
        event_queries: "analytics.repos.analytics_event_queries",
        feed_queries: "analytics.repos.feed_fetch_queries",
        post_queries: "posts.repos.post_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def call(range:)
        to = Blog::TimeZone.today
        from = to - (range - 1)
        before = rollup_queries.totals(from: from - range, to: from - 1).to_h
        found = period(from, to)

        {
          feed: feed_queries.feed_subscribers_between(from:, to:),
          range:,
          webmentions: webmentions(from, to),
          weekday_hours: event_queries.weekday_hours(to:),
          **found,
          **stats(found.fetch(:totals), before),
        }
      end

      private

      def mentioned_posts(counts)
        rows = post_queries.by_ids(counts.keys).map { { count: counts.fetch(it.id), title: it.title } }

        rows.sort_by { [-it[:count], it[:title]] }.take(TOP_ROWS)
      end

      def period(from, to)
        summary = rollup_queries.summary_between(from:, to:)

        {
          **RANKED.to_h { [it, summary.fetch(it).take(TOP_ROWS)] },
          series: summary.fetch(:days),
          totals: summary.fetch(:totals),
        }
      end

      def stats(totals, before)
        views = totals.fetch(:views)
        prior = before.fetch(:views)

        {
          change: (Blog::Helpers::Figures.share(views - prior, prior) if prior.positive?),
          per_visit: Blog::Helpers::Figures.rate(views, totals.fetch(:visitors)),
          read_time: Blog::Helpers::Figures.average(totals.fetch(:read_seconds), views),
        }
      end

      def webmentions(from, to)
        {
          pending: webmention_queries.pending_count,
          posts: mentioned_posts(webmention_queries.received_by_post(from:, to:)),
          received: webmention_queries.received_between(from:, to:),
        }
      end
    end
  end
end
