# frozen_string_literal: true

module API
  module Endpoints
    class EditDecision < DecisionEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Decisions::ID,
          title: { type: "string" },
          problem: { type: "string", description: "the problem, in Markdown" },
          note: Decisions::NOTE,
        },
        required: ["id"],
      }.freeze

      include Deps[edit_decision: "decisions.operations.edit_decision"]

      def handle(id:, **fields)
        decision = decision_queries.by_id(id)
        return not_found(Helpers::Wording.missing("decision", id)) if decision.nil?

        params = { title: decision.title, problem: decision.problem }.merge(fields)
        settled(edit_decision.call(id, params), id)
      end
    end
  end
end
