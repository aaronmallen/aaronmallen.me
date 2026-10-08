# frozen_string_literal: true

module Analytics
  module Repos
    class PostReaderQueries < DB::Repo
      NONE = { readers: nil, final: true }.freeze
      UNREAD = { readers: 0, final: false }.freeze

      def readers_by_path(paths)
        live = by_path(post_reader_hashes.for_paths(paths).counts_by_path)
        saved = by_path(post_reader_counts.for_paths(paths))

        (saved.keys | live.keys).to_h do |path|
          [path, { readers: saved.fetch(path, 0) + live.fetch(path, 0), final: !live.key?(path) }]
        end
      end

      def unique_readers(posts, since: Readers.window_opened_at)
        counts = readers_by_path(posts.map { path(it) })

        posts.to_h { |post| [post.id, counts.fetch(path(post)) { counted?(post, since) ? UNREAD : NONE }] }
      end

      private

      def by_path(relation) = relation.to_a.to_h { [it.path, it.readers] }

      def counted?(post, since) = post.published_at.nil? || post.published_at > since

      def path(post) = "#{Hanami.app.settings.writing_path}/#{post.slug}"
    end
  end
end
