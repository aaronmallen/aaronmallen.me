# frozen_string_literal: true

module API
  module Endpoints
    class ListDecisions < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          page: Blog::Paging::PAGE,
          status: {
            type: "string",
            enum: Blog::Types::DecisionStatus.values,
            description: "open, resolved or dropped; every status when you leave it out",
          },
          tag: { type: "string", description: "a private tag the decision carries; any tag when you leave it out" },
        },
      }.freeze

      REPLY = Schema.object(
        { count: Schema::INTEGER, decisions: Schema.list(Serializers::Decision.reference), partial: Schema::BOOLEAN },
        optional: { next_page: Schema::INTEGER },
      ).freeze

      include Deps["settings", find_decisions: "decisions.queries.find_decisions"]

      def handle(page: 1, status: nil, tag: nil)
        found = find_decisions.call(page: Blog::Page.new(number: page, size: settings.page_size[:mcp]), status:,
                                    tag: tag&.downcase)

        Success(
          { count: found.rows.length, decisions: serialized(Serializers::Decision, found.rows),
            **Blog::Paging.fields(found) },
        )
      end
    end
  end
end
