# frozen_string_literal: true

module Security
  module Operations
    class RecordSignIn
      SIGNED_IN = Blog::Types::SignInOutcome["signed_in"]

      include Deps[
        "operations.read_access",
        "settings",
        device_mutations: "repos.device_mutations",
        device_queries: "repos.device_queries",
        hash_visitor: "analytics.operations.hash_visitor",
        known_device_mutations: "repos.known_device_mutations",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(request, outcome, provider:, device: nil)
        access = read_access.call(request)
        outcome = Blog::Types::SignInOutcome[outcome.to_s]
        visitor_hashes = hash_visitor.throttle_hashes(access[:address])
        device = Blog::Types::UuidParam[device]
        row = { outcome:, provider: Blog::Types::SignInProvider[provider.to_s], visitor_hash: visitor_hashes.first }
        return claim_failure(visitor_hashes, device_queries.known(device), **row, **access) unless outcome == SIGNED_IN

        sign_in(device, row, access)
      end

      private

      def claim_failure(visitor_hashes, device_id, **row)
        throttle = Blog::Throttle.new(settings.sign_ins)

        sign_in_mutations.claim_failure(visitor_hashes:, since: throttle.since, limit: throttle.limit, device_id:,
                                        **row)
        device_id
      end

      def sign_in(device, row, access)
        device_id = device_mutations.sign_in(device, **access.slice(:browser, :os))
        known_device_mutations.know(**access.slice(*ReadAccess::DEVICE))
        sign_in_mutations.create(**row, **access, device_id:)
        device_id
      end
    end
  end
end
