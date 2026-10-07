# frozen_string_literal: true

module API
  module Queries
    class PostFigures
      include Deps[
        post_reader_queries: "analytics.repos.post_reader_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      COUNTS = { read_through_counts: :read_throughs, view_counts: :views, visitor_counts: :visitors }.freeze
      UNSEEN = COUNTS.values.to_h { [it, 0] }.freeze

      def call(posts)
        ids = posts.map(&:id)
        seen = rollup_queries.views_by_post(ids)
        figures = ids.to_h { [it, seen.fetch(it, UNSEEN)] }

        {
          **COUNTS.transform_values { |key| figures.transform_values { it.fetch(key) } },
          unique_reader_counts: post_reader_queries.unique_readers(posts),
          webmention_counts: webmention_queries.count_by_post(ids),
          word_counts: posts.to_h { [it.id, ::Posts::Markdown.word_count(it.body)] },
        }
      end
    end
  end
end
