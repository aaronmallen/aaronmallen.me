# frozen_string_literal: true

module Decisions
  module Operations
    class ReopenDecision < Blog::Operation
      OPEN = Blog::Types::DecisionStatus["open"]
      REOPENED = Blog::Types::DecisionEventKind["reopened"]

      include Deps[
        contract: "contracts.reason_contract",
        decision_mutations: "repos.decision_mutations",
        decision_queries: "repos.decision_queries",
        reopen_decision_task: "tasks.operations.reopen_decision_task",
      ]

      def call(id, params)
        fields = step validated(contract.call(reason: params[:reason]))

        transaction do
          step reopen(step(find(id)), fields[:reason])
          decision_queries.by_id(id)
        end
      end

      private

      def find(id)
        found(decision_mutations.by_id_for_update(id)).bind { it.closed? ? Success(it) : Failure(:open) }
      end

      def reopen(decision, reason)
        decision_mutations.update(decision.id, status: OPEN, resolved_option_id: nil)
        decision_mutations.record(decision.id, REOPENED, reason:)
        reopen_decision_task.call(decision.id, decision.title)
      end
    end
  end
end
