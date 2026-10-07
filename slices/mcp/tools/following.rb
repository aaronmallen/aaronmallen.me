# frozen_string_literal: true

module MCP
  module Tools
    module Following
      DESCRIPTION = "feed counts the people who follow the site's feeds: days gives subscribers each day, the count " \
                    "feed aggregators such as Feedly report plus the other readers that fetched a feed; latest " \
                    "gives that count for the last day of the range, or yesterday when the range runs to today; " \
                    "and aggregators gives each aggregator's latest count in the range, summed across the feeds, " \
                    "most first. webmentions gives pending, the webmentions waiting for review now whatever the " \
                    "range; received, the webmentions that came in over the range in any state; and posts, the " \
                    "top %<top>d posts by webmentions received over the range, each with its post_id, title and " \
                    "received. "
      QUERIES = %i[feed_fetch_queries post_queries webmention_queries].freeze

      module_function

      def call(range, top:, **queries)
        window = { from: range.first, to: range.last }

        { feed: feed(queries.fetch(:feed_fetch_queries).feed_subscribers_between(**window)),
          webmentions: webmentions(window, top, queries) }
      end

      def feed(found) = found.merge(days: found.fetch(:days).map { it.merge(day: it.fetch(:day).iso8601) })

      def posts(counts, post_queries)
        post_queries.by_ids(counts.keys).map { { post_id: it.id, title: it.title, received: counts.fetch(it.id) } }
      end

      def webmentions(window, top, queries)
        webmention_queries = queries.fetch(:webmention_queries)
        counts = webmention_queries.received_by_post(**window)

        {
          pending: webmention_queries.pending_count,
          received: webmention_queries.received_between(**window),
          posts: posts(counts, queries.fetch(:post_queries)).sort_by { [-it[:received], it[:title]] }.take(top),
        }
      end
    end
  end
end
