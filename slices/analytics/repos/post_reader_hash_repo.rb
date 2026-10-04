# frozen_string_literal: true

module Analytics
  module Repos
    class PostReaderHashRepo < Blog::DB::Repo
      def live_counts(paths) = by_path(post_reader_hashes.for_paths(paths).counts_by_path)

      def record(path:, reader_hash:, since: Readers.window_opened_at)
        post_reader_hashes.record(path:, reader_hash:, since:)
      end

      def save_counts(since:)
        transaction do
          closed = post_reader_hashes.closed(since)
          post_reader_counts.save(closed.counts_by_path)
          closed.delete
        end
      end

      def saved_counts(paths) = by_path(post_reader_counts.for_paths(paths))

      private

      def by_path(relation) = relation.to_a.to_h { [it.path, it.readers] }
    end
  end
end
