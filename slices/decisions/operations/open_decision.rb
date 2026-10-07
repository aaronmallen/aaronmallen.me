# frozen_string_literal: true

module Decisions
  module Operations
    class OpenDecision < Operation
      FIELDS = %i[title problem tags].freeze
      OPENED = Blog::Types::DecisionEventKind["opened"]

      include Deps[contract: "contracts.decision_contract", decision_repo: "repos.decision_repo"]

      def call(params)
        fields = step validate(params)

        transaction do
          decision = decision_repo.create(**fields.except(:tags))
          decision_repo.replace_tags(decision.id, fields.fetch(:tags))
          decision_repo.record(decision.id, OPENED)
          decision_repo.by_id(decision.id)
        end
      end

      private

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
