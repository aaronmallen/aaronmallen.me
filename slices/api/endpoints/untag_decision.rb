# frozen_string_literal: true

module API
  module Endpoints
    class UntagDecision < DecisionTagging
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Decisions::ID, tag: { type: "string", description: "the tag to take off" } },
        required: %w[id tag],
      }.freeze

      def handle(id:, tag:)
        decision = decision_queries.by_id(id)
        return not_found(Wording.missing("decision", id)) if decision.nil?

        names = decision.tags.map(&:name)
        name = Blog::Types::TagList[tag].first
        return not_found("decision #{id} has no tag #{tag}") unless names.include?(name)

        retag(decision, names - [name])
      end
    end
  end
end
