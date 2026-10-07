# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostsPage
      include Deps[
        post_figure_queries: "api.repos.post_figure_queries",
        post_queries: "posts.repos.post_queries",
      ]

      def call(filter:, page:)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = post_queries.by_filter(chosen, page)

        { counts: post_queries.count_by_status, filter: chosen, posts:, **post_figure_queries.figures(posts.rows) }
      end
    end
  end
end
