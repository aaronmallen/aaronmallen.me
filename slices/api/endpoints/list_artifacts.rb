# frozen_string_literal: true

module API
  module Endpoints
    class ListArtifacts < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          page: Helpers::Paging::PAGE,
          query: { type: "string", description: "words to find in the title, the latest body or the tags" },
          type: Artifacts::TYPE.merge(description: "one type; every type when you leave it out"),
        },
      }.freeze

      REPLY = Helpers::Schema.paged(
        { count: Helpers::Schema::INTEGER, artifacts: Helpers::Schema.list(Serializers::Artifact.reference) },
      ).freeze

      include Deps[artifact_queries: "agents.repos.artifact_queries"]

      def handle(page: 1, query: nil, type: nil)
        found = artifact_queries.listed(page_of(page), type:, text: query.to_s.strip.then { it unless it.empty? })

        Success(
          {
            count: found.rows.length,
            artifacts: serialized(Serializers::Artifact, found.rows),
            **Helpers::Paging.fields(found),
          },
        )
      end
    end
  end
end
