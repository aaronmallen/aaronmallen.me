# frozen_string_literal: true

module API
  module Endpoints
    class ListDecisions < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          page: Blog::Helpers::Paging::PAGE,
          query: { type: "string", description: "words to find in the title or problem" },
          status: {
            type: "string",
            enum: Blog::Types::DecisionStatus.values,
            description: "open, resolved or dropped; every status when you leave it out",
          },
          tag: { type: "string", description: "a private tag the decision carries; any tag when you leave it out" },
        },
      }.freeze

      COUNTS = Helpers::Schema.object(
        Blog::Types::DecisionStatus.values.to_h { [it.to_sym, Helpers::Schema::INTEGER] },
      ).merge(
        description: "how many decisions with the query and tag given sit in each status, whatever status asks for",
      ).freeze

      REPLY = Helpers::Schema.object(
        {
          count: Helpers::Schema::INTEGER,
          counts: COUNTS,
          decisions: Helpers::Schema.list(Serializers::Decision.reference),
          partial: Helpers::Schema::BOOLEAN,
        },
        optional: { next_page: Helpers::Schema::INTEGER },
      ).freeze

      include Deps[
        "settings",
        decision_queries: "decisions.repos.decision_queries",
      ]

      def handle(page: 1, query: nil, status: nil, tag: nil)
        filters = { tag: tag&.downcase, text: query.to_s.strip.then { it unless it.empty? } }
        found = decision_queries.listed(page_of(page), status:, **filters)

        Success(
          {
            count: found.rows.length,
            counts: decision_queries.count_found(**filters),
            decisions: serialized(Serializers::Decision, found.rows),
            **Blog::Helpers::Paging.fields(found),
          },
        )
      end
    end
  end
end
