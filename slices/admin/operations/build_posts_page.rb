# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostsPage
      include Deps[
        check_post_links: "posts.operations.check_post_links",
        post_figure_queries: "posts.repos.post_figure_queries",
        post_queries: "posts.repos.post_queries",
        short_link_queries: "shares.repos.short_link_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
      ]

      PUBLISHED = Blog::Types::PostStatus["published"]

      def call(filter:, page:)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = post_queries.by_filter(chosen, page)

        {
          counts: post_queries.count_by_status, filter: chosen, posts:,
          failing_links: failing_links(posts.rows),
          link_check: link_check,
          suggestion_counts: suggestion_counts(posts.rows),
          **post_figure_queries.figures(posts.rows),
        }
      end

      private

      def failing_links(rows)
        published = rows.select { it.status == PUBLISHED }
        checks = post_queries.failing_links(published.map(&:id))
        bodies = post_queries.bodies(checks.keys)

        checks.to_h { |id, found| [id, link_rows(bodies.fetch(id), found)] }
      end

      def link_check
        {
          **post_queries.link_check_tally,
          run: post_queries.last_link_check_run,
          short_links: short_link_queries.failing,
          short_total: short_link_queries.totals[:count],
        }
      end

      def link_rows(body, checks)
        texts = check_post_links.links(body)

        checks.map { { url: it.url, text: texts.fetch(it.url, Blog::Constants::EMPTY_STRING), check: it } }
      end

      def suggestion_counts(rows)
        suggestion_queries.open_counts_for_posts(rows.reject { it.status == PUBLISHED }.map(&:id))
      end
    end
  end
end
