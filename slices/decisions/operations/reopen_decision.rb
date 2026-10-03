# frozen_string_literal: true

module Decisions
  module Operations
    class ReopenDecision < Blog::Operation
      OPEN = Blog::Types::DecisionStatus["open"]
      REOPENED = Blog::Types::DecisionEventKind["reopened"]

      include Deps[contract: "contracts.reason_contract", decision_repo: "repos.decision_repo"]

      def call(id, params)
        fields = step validated(contract.call(reason: params[:reason]))

        transaction do
          step find(id)
          decision_repo.update(id, status: OPEN, resolved_option_id: nil)
          decision_repo.record(id, REOPENED, reason: fields[:reason])
          decision_repo.by_id(id)
        end
      end

      private

      def find(id)
        decision = decision_repo.by_id_for_update(id)
        return Failure(:not_found) unless decision

        decision.closed? ? Success(decision) : Failure(:open)
      end
    end
  end
end
