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

      COUNTS = { read_through_counts: :read_throughs, view_counts: :views, visitor_counts: :visitors }.freeze
      UNSEEN = COUNTS.values.to_h { [it, 0] }.freeze

      def call(filter:, page:)
        chosen = Blog::Types::PostFilterParam[filter]
        posts = posts_by_filter.call(chosen, page)

        { counts: post_counts_by_status.call, filter: chosen, posts:, **tallies(posts.rows) }
      end

      private

      def tallies(posts)
        ids = posts.map(&:id)
        seen = views_by_post.call(ids)
        figures = ids.to_h { [it, seen.fetch(it, UNSEEN)] }

        {
          **COUNTS.transform_values { |key| figures.transform_values { it.fetch(key) } },
          webmention_counts: webmention_counts_by_post.call(ids),
          word_counts: posts.to_h { [it.id, ::Posts::Markdown.word_count(it.body)] },
        }
      end
    end
  end
end
