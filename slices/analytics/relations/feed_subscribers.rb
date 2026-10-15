# frozen_string_literal: true

module Analytics
  module Relations
    class FeedSubscribers < Blog::DB::Relation
      use :daily_rollup

      LATEST = { subscribers: Sequel[:excluded][:subscribers], updated_at: Sequel::CURRENT_TIMESTAMP }.freeze

      schema :feed_subscribers, infer: true

      def by_day = unordered.select { [day, integer.sum(subscribers).as(:subscribers)] }.group(:day)

      def record(day:, path:, aggregator:, subscribers:)
        latest = dataset.insert_conflict(target: %i[day path aggregator], update: LATEST)

        latest.insert(day:, path:, aggregator:, subscribers:)
      end
    end
  end
end
