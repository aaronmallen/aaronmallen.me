# frozen_string_literal: true

module Decisions
  module Operations
    class DropDecision < Blog::Operation
      EVENT = Blog::Types::DecisionEventKind["dropped"]
      STATUS = Blog::Types::DecisionStatus["dropped"]

      include Deps[
        close_decision_task: "tasks.operations.close_decision_task",
        contract: "contracts.reason_contract",
        decision_mutations: "repos.decision_mutations",
        decision_queries: "repos.decision_queries",
      ]

      def call(id, params)
        fields = step validated(contract.call(reason: params[:reason]))

        transaction do
          step find(id)
          step drop(id, fields[:reason])
          decision_queries.by_id(id)
        end
      end

      private

      def drop(id, reason)
        decision_mutations.update(id, status: STATUS)
        decision_mutations.record(id, EVENT, reason:)
        close_decision_task.call(id, canceled: true)
      end

      def find(id)
        found(decision_mutations.by_id_for_update(id)).bind { it.open? ? Success(it) : Failure(:closed) }
      end
    end
  end
end
