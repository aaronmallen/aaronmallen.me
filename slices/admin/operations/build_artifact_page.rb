# frozen_string_literal: true

module Admin
  module Operations
    class BuildArtifactPage
      include Blog::Constants

      KIND = Blog::Types::RecordKind["artifact"]

      include Deps[
        artifact_queries: "agents.repos.artifact_queries",
        list_record_links: "operations.list_record_links",
      ]

      def call(id, number: nil, records: EMPTY_HASH)
        artifact = artifact_queries.by_id(id)
        return unless artifact

        shown = (artifact_queries.version(id, number) if number) || artifact_queries.version(id, artifact.version)

        { artifact:, shown:, versions: artifact_queries.versions(id).reverse,
          records: list_record_links.call(KIND, id, **records) }
      end
    end
  end
end
