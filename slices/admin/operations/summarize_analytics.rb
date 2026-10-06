# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeAnalytics
      RANKED = %i[countries paths referrers].freeze
      TOP_ROWS = 10

      include Deps[
        feed_subscribers_between: "analytics.queries.feed_subscribers_between",
        pending_webmention_count: "social.queries.pending_webmention_count",
        posts_by_ids: "posts.queries.by_ids",
        summary_between: "analytics.queries.summary_between",
        view_totals: "analytics.queries.view_totals",
        webmentions_received_between: "social.queries.webmentions_received_between",
        webmentions_received_by_post: "social.queries.webmentions_received_by_post",
        weekday_hours: "analytics.queries.weekday_hours",
      ]

      def call(range:)
        to = Blog::TimeZone.today
        from = to - (range - 1)
        before = view_totals.call(from: from - range, to: from - 1).to_h
        found = period(from, to)

        {
          feed: feed_subscribers_between.call(from:, to:),
          range:,
          webmentions: webmentions(from, to),
          weekday_hours: weekday_hours.call(to:),
          **found,
          **stats(found.fetch(:totals), before),
        }
      end

      private

      def mentioned_posts(counts)
        rows = posts_by_ids.call(counts.keys).map { { count: counts.fetch(it.id), title: it.title } }

        rows.sort_by { [-it[:count], it[:title]] }.take(TOP_ROWS)
      end

      def period(from, to)
        summary = summary_between.call(from:, to:)

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
          change: (Blog::Figures.share(views - prior, prior) if prior.positive?),
          per_visit: Blog::Figures.rate(views, totals.fetch(:visitors)),
          read_time: Blog::Figures.average(totals.fetch(:read_seconds), views),
        }
      end

      def webmentions(from, to)
        {
          pending: pending_webmention_count.call,
          posts: mentioned_posts(webmentions_received_by_post.call(from:, to:)),
          received: webmentions_received_between.call(from:, to:),
        }
      end
    end
  end
end
