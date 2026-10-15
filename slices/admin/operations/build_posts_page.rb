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

        published.select { checks.key?(it.id) }.to_h { [it.id, link_rows(it, checks.fetch(it.id))] }
      end

      def link_check
        posts = post_queries.link_check_tally
        finished_at = [posts[:checked_at], short_link_queries.last_checked_at].compact.max

        {
          **posts.slice(:links, :posts),
          finished_at:,
          short_links: short_link_queries.failing,
          short_total: short_link_queries.totals[:count],
        }
      end

      def link_rows(post, checks)
        texts = check_post_links.links(post.body)

        checks.map { { url: it.url, text: texts.fetch(it.url, Blog::Constants::EMPTY_STRING), check: it } }
      end

      def suggestion_counts(rows)
        suggestion_queries.open_counts_for_posts(rows.reject { it.status == PUBLISHED }.map(&:id))
      end
    end
  end
end
