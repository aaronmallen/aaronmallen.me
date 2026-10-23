# frozen_string_literal: true

module Admin
  module Operations
    class BuildArtifactPage
      include Blog::Constants

      KIND = Blog::Types::RecordKind["artifact"]

      include Deps[
        artifact_queries: "agents.repos.artifact_queries",
        list_record_links: "operations.list_record_links",
        project_queries: "projects.repos.project_queries",
      ]

      def call(id, number: nil, records: EMPTY_HASH)
        artifact = artifact_queries.by_id(id)
        return unless artifact

        latest = artifact.version
        shown = (artifact_queries.version_row(id, number) if number) || artifact_queries.version_row(id, latest)

        versions = artifact_queries.versions(id)

        { artifact:, shown:, first_version: versions.first, versions: versions.reverse,
          records: list_record_links.call(KIND, id, **records),
          keys: project_queries.keys(artifact.tags.filter_map(&:project_id)) }
      end
    end
  end
end
