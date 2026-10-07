# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostsPage
      include Deps[
        post_figures: "api.queries.post_figures",
        post_queries: "posts.repos.post_queries",
      ]

      def call(filter:, page:)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = post_queries.by_filter(chosen, page)

        { counts: post_queries.count_by_status, filter: chosen, posts:, **post_figures.call(posts.rows) }
      end
    end
  end
end
