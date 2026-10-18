# frozen_string_literal: true

module API
  module Endpoints
    class ReadArtifact < ArtifactEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          version: Helpers::Schema::ID.merge(description: "the version whose body to give; the latest when left out"),
        },
        required: %w[id],
      }.freeze

      def handle(id:, version: nil)
        artifact = artifact_queries.by_id(id)
        return missing("artifact", id) if artifact.nil?
        return not_found(Artifacts.missing_version(id, version)) if version && version > artifact.version

        Success(replied(artifact, version || artifact.version))
      end
    end
  end
end
