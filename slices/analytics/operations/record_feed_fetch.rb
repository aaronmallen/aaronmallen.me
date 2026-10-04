# frozen_string_literal: true

module Analytics
  module Operations
    class RecordFeedFetch
      include Deps[feed_repo: "repos.feed_fetch_repo", hash_visitor: "operations.hash_visitor"]

      def call(path:, address:, user_agent:, signed_in: false)
        return if signed_in

        now = Time.now
        day = Blog::TimeZone.today(now)
        count = Aggregator.parse(user_agent)
        return feed_repo.record_subscribers(day:, path:, **count.to_h) if count

        feed_repo.record_reader(day:, path:, reader_hash: hash_visitor.call(address:, user_agent:, at: now))
      end
    end
  end
end
