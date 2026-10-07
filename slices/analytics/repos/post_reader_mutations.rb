# frozen_string_literal: true

module Analytics
  module Repos
    class PostReaderMutations < DB::Repo
      root :post_reader_hashes

      def record(path:, reader_hash:, since: Readers.window_opened_at)
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
