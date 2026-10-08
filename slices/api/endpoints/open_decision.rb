# frozen_string_literal: true

module API
  module Endpoints
    class OpenDecision < DecisionEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          title: { type: "string", description: "the decision to make" },
          problem: { type: "string", description: "the problem it solves, in Markdown" },
          tags: { type: "array", items: { type: "string" }, description: "private tags for it, lowercase words" },
        },
        required: %w[title problem],
      }.freeze

      include Deps[open_decision: "decisions.operations.open_decision"]

      def handle(title:, problem:, tags: nil)
        case open_decision.call({ title:, problem:, tags: Helpers::Wording.tag_list(tags) })
          in Success(decision) then answered(decision.id)
          in Failure[:invalid, errors] then rejected(errors, Decisions::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
