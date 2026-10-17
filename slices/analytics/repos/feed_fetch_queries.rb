# frozen_string_literal: true

module Analytics
  module Repos
    class FeedFetchQueries < Blog::DB::Repo
      def feed_subscribers_between(from:, to:)
        subscribers = subscribers_by_day(from, to)
        readers = readers_by_day(from, to)
        days = (from..to).to_h { [it, subscribers.fetch(it, 0) + readers.fetch(it, 0)] }

        { days: days.map { |day, count| { day:, subscribers: count } }, **latest(last_whole_day(to)) }
      end

      private

      def aggregators(rows)
        counts = rows.to_a.each_with_object(Hash.new(0)) { |row, found| found[row.aggregator] += row.subscribers }

        found = counts.map { |aggregator, subscribers| { aggregator:, subscribers: } }

        found.sort_by { [-it[:subscribers], it[:aggregator]] }
      end

      def last_whole_day(to) = [to, Blog::TimeZone.today.prev_day].min

      def latest(day)
        found = aggregators(feed_subscribers.on(day))
        readers = feed_readers.on(day).sum(:readers) || 0

        { aggregators: found, latest: found.sum { it[:subscribers] } + readers, readers: }
      end

      def readers_by_day(from, to) = feed_readers.between(from, to).by_day.to_a.to_h { [it.day, it.readers] }

      def subscribers_by_day(from, to)
        feed_subscribers.between(from, to).by_day.to_a.to_h { [it.day, it.subscribers] }
      end
    end
  end
end
