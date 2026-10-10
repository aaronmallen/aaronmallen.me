# frozen_string_literal: true

module Decisions
  module Operations
    class DropDecision < Blog::Operation
      EVENT = Blog::Types::DecisionEventKind["dropped"]
      STATUS = Blog::Types::DecisionStatus["dropped"]

      include Deps[
        contract: "contracts.reason_contract",
        decision_mutations: "repos.decision_mutations",
        decision_queries: "repos.decision_queries",
      ]

      def call(id, params)
        fields = step validated(contract.call(reason: params[:reason]))

        transaction do
          step find(id)
          decision_mutations.update(id, status: STATUS)
          decision_mutations.record(id, EVENT, reason: fields[:reason])
          decision_queries.by_id(id)
        end
      end

      private

      def find(id)
        found(decision_mutations.by_id_for_update(id)).bind { it.open? ? Success(it) : Failure(:closed) }
      end
    end
  end
end
