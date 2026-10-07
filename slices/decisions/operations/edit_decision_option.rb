# frozen_string_literal: true

module Decisions
  module Operations
    class EditDecisionOption < Operation
      FIELDS = %i[title body note].freeze
      OPTION_EDITED = Blog::Types::DecisionEventKind["option_edited"]

      include Deps[
        contract: "contracts.decision_option_contract",
        decision_mutations: "repos.decision_mutations",
        decision_option_mutations: "repos.decision_option_mutations",
        decision_queries: "repos.decision_queries",
        require_edit_note: "operations.require_edit_note",
      ]

      def call(decision_id, id, params)
        fields = step validate(params)

        transaction do
          decision, option = step find(decision_id, id)
          step revise(decision, option, **fields)
        end
      end

      private

      def find(decision_id, id)
        decision = decision_mutations.by_id_for_update(decision_id)
        option = decision && decision_queries.option_on_decision(decision_id, id)

        found(option && [decision, option])
      end

      def revise(decision, option, title:, body:, note:)
        return Success(option) if option.title == title && option.body == body

        kept = step require_edit_note.call(needed: decision.closed?, note:)
        saved = decision_option_mutations.update(option.id, title:, body:)
        decision_mutations.record(decision.id, OPTION_EDITED, option_id: option.id, note: kept)
        Success(saved)
      end

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
