# frozen_string_literal: true

module Admin
  module Operations
    class BuildPostsPage
      ALL = Blog::Types::PostFilter["all"]

      include Deps[
        all_posts: "posts.queries.all",
        post_counts_by_status: "posts.queries.count_by_status",
        posts_by_status: "posts.queries.by_status",
        views_by_post: "analytics.queries.views_by_post",
        webmention_counts_by_post: "social.queries.webmention_counts_by_post",
      ]

      def call(filter: ALL)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = chosen == ALL ? all_posts.call : posts_by_status.call(chosen)

        { counts: post_counts_by_status.call, filter: chosen, posts:, **tallies(posts) }
      end

      private

      def tallies(posts)
        views = views_by_post.call

        {
          view_counts: posts.to_h { [it.id, views.fetch(it.id, 0)] },
          webmention_counts: webmention_counts_by_post.call(posts.map(&:id)),
          word_counts: posts.to_h { [it.id, ::Posts::Markdown.word_count(it.body)] },
        }
      end
    end
  end
end
