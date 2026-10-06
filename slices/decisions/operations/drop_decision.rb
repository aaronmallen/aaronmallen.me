# frozen_string_literal: true

module Decisions
  module Operations
    class DropDecision < Blog::Operation
      EVENT = Blog::Types::DecisionEventKind["dropped"]
      STATUS = Blog::Types::DecisionStatus["dropped"]

      include Deps[contract: "contracts.reason_contract", decision_repo: "repos.decision_repo"]

      def call(id, params)
        fields = step validated(contract.call(reason: params[:reason]))

        transaction do
          step find(id)
          decision_repo.update(id, status: STATUS)
          decision_repo.record(id, EVENT, reason: fields[:reason])
          decision_repo.by_id(id)
        end
      end

      private

      def find(id)
        found(decision_repo.by_id_for_update(id)).bind { it.open? ? Success(it) : Failure(:closed) }
      end
    end
  end
end
