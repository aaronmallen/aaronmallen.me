# frozen_string_literal: true

module Decisions
  module Operations
    class AddDecisionOption < Operation
      FIELDS = %i[title body].freeze
      OPTION_ADDED = Blog::Types::DecisionEventKind["option_added"]

      include Deps[
        contract: "contracts.decision_option_contract",
        decision_mutations: "repos.decision_mutations",
        decision_option_mutations: "repos.decision_option_mutations",
      ]

      def call(decision_id, params)
        fields = step validate(params)

        transaction do
          step find(decision_id)
          option = decision_option_mutations.create(decision_id:, **fields)
          decision_mutations.record(decision_id, OPTION_ADDED, option_id: option.id)
          option
        end
      end

      private

      def find(id)
        found(decision_mutations.by_id_for_update(id)).bind { it.open? ? Success(it) : Failure(:closed) }
      end

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
