# frozen_string_literal: true

module Analytics
  module Repos
    class PostReaderMutations < Blog::DB::Repo
      root :post_reader_hashes

      include Deps[reader_window_start: "operations.find_reader_window_start"]

      def record(path:, reader_hash:, since: reader_window_start.call)
        post_reader_hashes.record(path:, reader_hash:, since:)
      end

      def save_counts(since:)
        transaction do
          closed = post_reader_hashes.closed(since)
          post_reader_counts.save(closed.counts_by_path)
          closed.delete
          post_reader_hashes.orphaned.delete
        end
      end
    end
  end
end
