# frozen_string_literal: true

module Decisions
  module Operations
    class DeleteDecisionOption < Blog::Operation
      CHOSEN = "decisions_resolved_option_fkey"

      include Deps[
        decision_option_mutations: "repos.decision_option_mutations",
        decision_queries: "repos.decision_queries",
      ]

      def call(decision_id, id)
        step find(decision_id, id)
        step remove(id)
      end

      private

      def find(decision_id, id) = found(decision_queries.option_on_decision(decision_id, id) && id)

      def remove(id)
        Success(transaction { decision_option_mutations.delete(id) })
      rescue ROM::SQL::ForeignKeyConstraintError => e
        raise unless decision_option_mutations.violated_constraint(e) == CHOSEN

        Failure([:invalid, { id: ["chosen"] }])
      end
    end
  end
end
