# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostsPage
      include Deps[
        post_counts_by_status: "posts.queries.count_by_status",
        post_figures: "api.queries.post_figures",
        posts_by_filter: "posts.queries.by_filter",
      ]

      def call(filter:, page:)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = posts_by_filter.call(chosen, page)

        { counts: post_counts_by_status.call, filter: chosen, posts:, **post_figures.call(posts.rows) }
      end
    end
  end
end
