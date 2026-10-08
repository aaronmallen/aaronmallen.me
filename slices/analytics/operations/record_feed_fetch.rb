# frozen_string_literal: true

module Analytics
  module Operations
    class RecordFeedFetch
      include Deps[
        feed_mutations: "repos.feed_fetch_mutations",
        hash_visitor: "operations.hash_visitor",
        parse_aggregator: "operations.parse_aggregator",
      ]

      def call(path:, address:, user_agent:, signed_in: false)
        return if signed_in

        now = Time.now
        day = Blog::TimeZone.today(now)
        count = parse_aggregator.call(user_agent)
        return feed_mutations.record_subscribers(day:, path:, **count.to_h) if count

        feed_mutations.record_reader(day:, path:, reader_hash: hash_visitor.call(address:, user_agent:, at: now))
      end
    end
  end
end
