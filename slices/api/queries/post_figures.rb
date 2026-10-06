# frozen_string_literal: true

module API
  module Queries
    class PostFigures
      include Deps[
        readers_by_path: "analytics.queries.readers_by_path",
        views_by_post: "analytics.queries.views_by_post",
        webmention_counts_by_post: "social.queries.webmention_counts_by_post",
      ]

      COUNTS = { read_through_counts: :read_throughs, view_counts: :views, visitor_counts: :visitors }.freeze
      UNSEEN = COUNTS.values.to_h { [it, 0] }.freeze

      def call(posts)
        ids = posts.map(&:id)
        seen = views_by_post.call(ids)
        figures = ids.to_h { [it, seen.fetch(it, UNSEEN)] }

        {
          **COUNTS.transform_values { |key| figures.transform_values { it.fetch(key) } },
          unique_reader_counts: unique_readers(posts),
          webmention_counts: webmention_counts_by_post.call(ids),
          word_counts: posts.to_h { [it.id, ::Posts::Markdown.word_count(it.body)] },
        }
      end

      private

      def unique_readers(posts)
        counts = readers_by_path.call(posts.map { Analytics::UniqueReaders.path(it) })

        posts.to_h { [it.id, Analytics::UniqueReaders.of(it, counts)] }
      end
    end
  end
end
