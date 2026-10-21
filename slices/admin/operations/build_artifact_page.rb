# frozen_string_literal: true

module Admin
  module Operations
    class BuildArtifactPage
      include Blog::Constants

      KIND = Blog::Types::RecordKind["artifact"]
      TAG_SCOPE = Blog::Types::TagScope["private"]

      include Deps[
        artifact_queries: "agents.repos.artifact_queries",
        list_record_links: "operations.list_record_links",
        tag_queries: "tags.repos.tag_queries",
      ]

      def call(id, number: nil, records: EMPTY_HASH)
        artifact = artifact_queries.by_id(id)
        return unless artifact

        latest = artifact.version
        shown = (artifact_queries.version_row(id, number) if number) || artifact_queries.version_row(id, latest)

        versions = artifact_queries.versions(id)

        { artifact:, shown:, first_version: versions.first, versions: versions.reverse,
          records: list_record_links.call(KIND, id, **records),
          colors: tag_queries.colors_named(TAG_SCOPE, artifact.tags) }
      end
    end
  end
end
