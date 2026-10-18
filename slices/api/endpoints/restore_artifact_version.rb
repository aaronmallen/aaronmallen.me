# frozen_string_literal: true

module API
  module Endpoints
    class RestoreArtifactVersion < ArtifactEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          version: Helpers::Schema::ID.merge(description: "the version whose body to copy forward"),
          note: Artifacts::NOTE.merge(description: "why; Restored version N when left out"),
          **Memory::AUTHOR,
        },
        required: %w[id version agent model],
      }.freeze

      include Deps[restore_artifact_version: "agents.operations.restore_artifact_version"]

      def handle(id:, version:, **fields)
        return missing("artifact", id) if artifact_queries.by_id(id).nil?

        result = restore_artifact_version.call(id, version, fields)
        settled(result, id, missing: Artifacts.missing_version(id, version)) { replied(it) }
      end
    end
  end
end
