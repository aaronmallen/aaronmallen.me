# frozen_string_literal: true

module Security
  module Operations
    class RecordSignIn < Operation
      include Deps[
        find_place: "analytics.operations.find_place",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(request, outcome)
        Success(sign_in_mutations.create(outcome: outcome.to_s, **Access.read(request, find_place)))
      end
    end
  end
end
