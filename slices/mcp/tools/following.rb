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
      QUERIES = %i[
        feed_fetch_queries pending_webmention_count posts_by_ids webmentions_received_between
        webmentions_received_by_post
      ].freeze

      module_function

      def call(range, top:, **queries)
        window = { from: range.first, to: range.last }

        { feed: feed(queries.fetch(:feed_fetch_queries).feed_subscribers_between(**window)),
          webmentions: webmentions(window, top, queries) }
      end

      def feed(found) = found.merge(days: found.fetch(:days).map { it.merge(day: it.fetch(:day).iso8601) })

      def posts(counts, posts_by_ids)
        posts_by_ids.call(counts.keys).map { { post_id: it.id, title: it.title, received: counts.fetch(it.id) } }
      end

      def webmentions(window, top, queries)
        counts = queries.fetch(:webmentions_received_by_post).call(**window)

        {
          pending: queries.fetch(:pending_webmention_count).call,
          received: queries.fetch(:webmentions_received_between).call(**window),
          posts: posts(counts, queries.fetch(:posts_by_ids)).sort_by { [-it[:received], it[:title]] }.take(top),
        }
      end
    end
  end
end
