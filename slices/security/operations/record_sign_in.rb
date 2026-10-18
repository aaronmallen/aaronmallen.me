# frozen_string_literal: true

module Security
  module Operations
    class RecordSignIn
      SIGNED_IN = Blog::Types::SignInOutcome["signed_in"]

      include Deps[
        "operations.read_access",
        "settings",
        hash_visitor: "analytics.operations.hash_visitor",
        known_device_mutations: "repos.known_device_mutations",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(request, outcome, provider:)
        access = read_access.call(request)
        outcome = Blog::Types::SignInOutcome[outcome.to_s]
        visitor_hashes = hash_visitor.throttle_hashes(access[:address])
        row = { outcome:, provider: Blog::Types::SignInProvider[provider.to_s], visitor_hash: visitor_hashes.first }
        return claim_failure(visitor_hashes, **row, **access) unless outcome == SIGNED_IN

        known_device_mutations.know(**access.slice(*ReadAccess::DEVICE))
        sign_in_mutations.create(**row, **access)
      end

      private

      def claim_failure(visitor_hashes, **row)
        throttle = Blog::Throttle.new(settings.sign_ins)

        sign_in_mutations.claim_failure(visitor_hashes:, since: throttle.since, limit: throttle.limit, **row)
      end
    end
  end
end
