# frozen_string_literal: true

module Analytics
  module Repos
    class FeedFetchMutations < Blog::DB::Repo
      root :feed_readers

      def delete_hashes_before(day) = feed_reader_hashes.before(day).delete

      def record_reader(day:, path:, reader_hash:) = feed_readers.record(day:, path:, reader_hash:)

      def record_subscribers(day:, path:, aggregator:, subscribers:)
        feed_subscribers.record(day:, path:, aggregator:, subscribers:)
      end
    end
  end
end
