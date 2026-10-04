# frozen_string_literal: true

module Analytics
  module Repos
    class FeedFetchRepo < Blog::DB::Repo
      def delete_hashes_before(day) = feed_reader_hashes.before(day).delete

      def latest_subscribers(from:, to:) = feed_subscribers.between(from, to).latest_per_feed.to_a

      def readers_by_day(from:, to:) = feed_readers.between(from, to).by_day.to_a.to_h { [it.day, it.readers] }

      def record_reader(day:, path:, reader_hash:) = feed_readers.record(day:, path:, reader_hash:)

      def record_subscribers(day:, path:, aggregator:, subscribers:)
        feed_subscribers.record(day:, path:, aggregator:, subscribers:)
      end

      def subscribers_by_day(from:, to:)
        feed_subscribers.between(from, to).by_day.to_a.to_h { [it.day, it.subscribers] }
      end
    end
  end
end
