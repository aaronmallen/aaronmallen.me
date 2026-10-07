# frozen_string_literal: true

module Decisions
  module Operations
    class EditDecision < Operation
      EDITED = Blog::Types::DecisionEventKind["edited"]
      FIELDS = %i[title problem note].freeze

      include Deps[
        contract: "contracts.decision_contract",
        decision_mutations: "repos.decision_mutations",
        decision_queries: "repos.decision_queries",
        require_edit_note: "operations.require_edit_note",
      ]

      def call(id, params)
        fields = step validate(params)

        transaction do
          step revise(step(find(id)), **fields)
          decision_mutations.replace_tags(id, fields[:tags]) if fields.key?(:tags)
          decision_queries.by_id(id)
        end
      end

      private

      def find(id)
        found(decision_mutations.by_id_for_update(id))
      end

      def form(params) = FIELDS.to_h { [it, params[it]] }.merge(params.slice(:tags))

      def revise(decision, title:, problem:, note:, **)
        edited = decision.problem != problem
        return Success(decision) unless edited || decision.title != title

        kept = step require_edit_note.call(needed: edited && decision.closed?, note:)
        decision_mutations.update(decision.id, title:, problem:)
        Success(decision_mutations.record(decision.id, EDITED, note: kept))
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
