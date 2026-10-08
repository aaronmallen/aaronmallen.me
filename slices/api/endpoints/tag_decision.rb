# frozen_string_literal: true

module API
  module Endpoints
    class TagDecision < DecisionTagging
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Decisions::ID,
          tags: {
            type: "array",
            items: { type: "string" },
            minItems: 1,
            description: "private tags to add, lowercase words; tags it already carries stay",
          },
        },
        required: %w[id tags],
      }.freeze

      def handle(id:, tags:)
        decision = decision_queries.by_id(id)
        return not_found(Helpers::Wording.missing("decision", id)) if decision.nil?

        retag(decision, decision.tags.map(&:name) + tags)
      end
    end
  end
end
