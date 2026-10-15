# frozen_string_literal: true

module Search
  module Operations
    class ClaimSearchAttempt < Blog::Operation
      include Deps[
        "settings",
        attempt_mutations: "repos.search_attempt_mutations",
        hash_visitor: "analytics.operations.hash_visitor",
      ]

      def call(address)
        claimed = attempt_mutations.claim(
          visitor_hashes: hash_visitor.throttle_hashes(address), since: throttle.since, limit: throttle.limit,
        )

        step(claimed ? Success(claimed) : Failure(Blog::Throttle::THROTTLED))
      end

      private

      def throttle = Blog::Throttle.new(settings.search)
    end
  end
end
