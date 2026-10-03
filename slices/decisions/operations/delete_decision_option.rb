# frozen_string_literal: true

module Decisions
  module Operations
    class DeleteDecisionOption < Blog::Operation
      CHOSEN = "decisions_resolved_option_fkey"

      include Deps[decision_option_repo: "repos.decision_option_repo"]

      def call(decision_id, id)
        step find(decision_id, id)
        step remove(id)
      end

      private

      def find(decision_id, id) = decision_option_repo.on_decision(decision_id, id) ? Success(id) : Failure(:not_found)

      def remove(id)
        Success(transaction { decision_option_repo.delete(id) })
      rescue ROM::SQL::ForeignKeyConstraintError => e
        raise unless decision_option_repo.violated_constraint(e) == CHOSEN

        Failure([:invalid, { id: ["chosen"] }])
      end
    end
  end
end
