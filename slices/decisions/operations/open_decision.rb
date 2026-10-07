# frozen_string_literal: true

module Decisions
  module Operations
    class OpenDecision < Operation
      FIELDS = %i[title problem tags].freeze
      OPENED = Blog::Types::DecisionEventKind["opened"]

      include Deps[
        contract: "contracts.decision_contract",
        decision_mutations: "repos.decision_mutations",
        decision_queries: "repos.decision_queries",
      ]

      def call(params)
        fields = step validate(params)

        transaction do
          decision = decision_mutations.create(**fields.except(:tags))
          decision_mutations.replace_tags(decision.id, fields.fetch(:tags))
          decision_mutations.record(decision.id, OPENED)
          decision_queries.by_id(decision.id)
        end
      end

      private

      def validate(params) = validated(contract.call(FIELDS.to_h { [it, params[it]] }))
    end
  end
end
