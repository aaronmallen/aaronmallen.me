# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostsPage
      include Deps[
        post_figure_queries: "api.repos.post_figure_queries",
        post_queries: "posts.repos.post_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
      ]

      PUBLISHED = Blog::Types::PostStatus["published"]

      def call(filter:, page:)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = post_queries.by_filter(chosen, page)

        {
          counts: post_queries.count_by_status, filter: chosen, posts:,
          suggestion_counts: suggestion_counts(posts.rows),
          **post_figure_queries.figures(posts.rows),
        }
      end

      private

      def suggestion_counts(rows)
        suggestion_queries.open_counts_for_posts(rows.reject { it.status == PUBLISHED }.map(&:id))
      end
    end
  end
end
