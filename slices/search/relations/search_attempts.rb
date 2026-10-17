# frozen_string_literal: true

module Search
  module Relations
    class SearchAttempts < Blog::DB::Relation
      schema :search_attempts, infer: true

      def claim(visitor_hashes:, since:, limit:, at: Time.now)
        transaction do
          lock_senders_until_commit(visitor_hashes)
          next unless where(visitor_hash: visitor_hashes).made_since(since).count < limit

          insert(visitor_hash: visitor_hashes.first, attempted_at: at)
        end
      end

      def made_before(time) = where { attempted_at < time }

      def made_since(time) = where { attempted_at >= time }
    end
  end
end
