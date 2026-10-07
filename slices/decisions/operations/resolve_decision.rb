# frozen_string_literal: true

module Decisions
  module Operations
    class ResolveDecision < Operation
      CHOICE = "decisions_resolved_option_fkey"
      EVENT = Blog::Types::DecisionEventKind["resolved"]
      FIELDS = %i[option_id reason].freeze
      STATUS = Blog::Types::DecisionStatus["resolved"]

      include Deps[contract: "contracts.resolution_contract", decision_repo: "repos.decision_repo"]

      def call(id, params)
        fields = step validate(params)
        step persist(id, **fields)

        decision_repo.by_id(id)
      end

      private

      def find(id)
        found(decision_repo.by_id_for_update(id)).bind { it.open? ? Success(it) : Failure(:closed) }
      end

      def persist(id, option_id:, reason:)
        transaction do
          step find(id)
          decision_repo.update(id, status: STATUS, resolved_option_id: option_id)
          Success(decision_repo.record(id, EVENT, option_id:, reason:))
        end
      rescue ROM::SQL::ForeignKeyConstraintError => e
        raise unless decision_repo.violated_constraint(e) == CHOICE

        Failure([:invalid, { option_id: ["missing"] }])
      end

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
