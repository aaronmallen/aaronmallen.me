# frozen_string_literal: true

module Security
  module Operations
    class RecordSignIn
      SIGNED_IN = Blog::Types::SignInOutcome["signed_in"]

      include Deps[
        "operations.read_access",
        known_device_mutations: "repos.known_device_mutations",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(request, outcome, provider:)
        access = read_access.call(request)
        outcome = Blog::Types::SignInOutcome[outcome.to_s]

        known_device_mutations.know(**access.slice(*ReadAccess::DEVICE)) if outcome == SIGNED_IN
        sign_in_mutations.create(outcome:, provider: Blog::Types::SignInProvider[provider.to_s], **access)
      end
    end
  end
end
