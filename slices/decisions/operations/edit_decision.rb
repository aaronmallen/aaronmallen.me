# frozen_string_literal: true

module Decisions
  module Operations
    class EditDecision < Blog::Operation
      EDITED = Blog::Types::DecisionEventKind["edited"]
      FIELDS = %i[title problem note].freeze

      include Deps[contract: "contracts.decision_contract", decision_repo: "repos.decision_repo"]

      def call(id, params)
        fields = step validate(params)

        transaction do
          step revise(step(find(id)), **fields)
          decision_repo.replace_tags(id, fields[:tags]) if fields.key?(:tags)
          decision_repo.by_id(id)
        end
      end

      private

      def find(id)
        decision = decision_repo.by_id_for_update(id)
        decision ? Success(decision) : Failure(:not_found)
      end

      def form(params) = FIELDS.to_h { [it, params[it]] }.merge(params.slice(:tags))

      def revise(decision, title:, problem:, note:, **)
        edited = decision.problem != problem
        return Success(decision) unless edited || decision.title != title

        kept = step EditNote.call(needed: edited && decision.closed?, note:)
        decision_repo.update(decision.id, title:, problem:)
        Success(decision_repo.record(decision.id, EDITED, note: kept))
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
