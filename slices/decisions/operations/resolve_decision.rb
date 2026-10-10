# frozen_string_literal: true

module Decisions
  module Operations
    class ResolveDecision < Blog::Operation
      CHOICE = "decisions_resolved_option_fkey"
      EVENT = Blog::Types::DecisionEventKind["resolved"]
      STATUS = Blog::Types::DecisionStatus["resolved"]

      include Deps[
        contract: "contracts.resolution_contract",
        decision_mutations: "repos.decision_mutations",
        decision_queries: "repos.decision_queries",
      ]

      def call(id, params)
        fields = step validate(params)
        step persist(id, **fields)

        decision_queries.by_id(id)
      end

      private

      def find(id)
        found(decision_mutations.by_id_for_update(id)).bind { it.open? ? Success(it) : Failure(:closed) }
      end

      def persist(id, option_id:, reason:)
        transaction do
          step find(id)
          decision_mutations.update(id, status: STATUS, resolved_option_id: option_id)
          Success(decision_mutations.record(id, EVENT, option_id:, reason:))
        end
      rescue ROM::SQL::ForeignKeyConstraintError => e
        raise unless decision_mutations.violated_constraint(e) == CHOICE

        Failure([:invalid, { option_id: ["missing"] }])
      end

      def validate(params) = validated(contract.call(every_field(params)))
    end
  end
end
