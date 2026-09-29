# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostsPage
      include Deps[
        post_counts_by_status: "posts.queries.count_by_status",
        posts_by_filter: "posts.queries.by_filter",
        views_by_post: "analytics.queries.views_by_post",
        webmention_counts_by_post: "social.queries.webmention_counts_by_post",
      ]

      def call(filter:, page:)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = posts_by_filter.call(chosen, page)

        { counts: post_counts_by_status.call, filter: chosen, posts:, **tallies(posts.rows) }
      end

      private

      def tallies(posts)
        ids = posts.map(&:id)
        views = views_by_post.call(ids)

        {
          view_counts: ids.to_h { [it, views.fetch(it, 0)] },
          webmention_counts: webmention_counts_by_post.call(ids),
          word_counts: posts.to_h { [it.id, ::Posts::Markdown.word_count(it.body)] },
        }
      end
    end
  end
end
