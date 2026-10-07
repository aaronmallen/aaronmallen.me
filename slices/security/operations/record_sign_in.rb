# frozen_string_literal: true

module Security
  module Operations
    class RecordSignIn < Operation
      SIGNED_IN = :signed_in

      include Deps[
        find_place: "analytics.operations.find_place",
        known_device_mutations: "repos.known_device_mutations",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(request, outcome)
        access = Access.read(request, find_place)

        known_device_mutations.know(**access.slice(*Access::DEVICE)) if outcome == SIGNED_IN
        Success(sign_in_mutations.create(outcome: outcome.to_s, **access))
      end
    end
  end
end
