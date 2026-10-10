# frozen_string_literal: true

module Security
  module Operations
    class RecordSignIn
      SIGNED_IN = :signed_in

      include Deps[
        "operations.read_access",
        known_device_mutations: "repos.known_device_mutations",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(request, outcome)
        access = read_access.call(request)

        known_device_mutations.know(**access.slice(*ReadAccess::DEVICE)) if outcome == SIGNED_IN
        sign_in_mutations.create(outcome: outcome.to_s, **access)
      end
    end
  end
end
