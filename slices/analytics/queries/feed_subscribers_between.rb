# frozen_string_literal: true

module Analytics
  module Queries
    class FeedSubscribersBetween
      include Deps[feed_repo: "repos.feed_fetch_repo"]

      def call(from:, to:)
        subscribers = feed_repo.subscribers_by_day(from:, to:)
        readers = feed_repo.readers_by_day(from:, to:)

        days = (from..to).to_h { [it, subscribers.fetch(it, 0) + readers.fetch(it, 0)] }

        {
          aggregators: aggregators(feed_repo.latest_subscribers(from:, to:)),
          days: days.map { |day, count| { day:, subscribers: count } },
          latest: days.fetch([to, Blog::TimeZone.today.prev_day].min, 0),
        }
      end

      private

      def aggregators(rows)
        counts = rows.each_with_object(Hash.new(0)) { |row, found| found[row.aggregator] += row.subscribers }

        found = counts.map { |aggregator, subscribers| { aggregator:, subscribers: } }

        found.sort_by { [-it[:subscribers], it[:aggregator]] }
      end
    end
  end
end
