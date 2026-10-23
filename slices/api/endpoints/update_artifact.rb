# frozen_string_literal: true

module API
  module Endpoints
    class UpdateArtifact < ArtifactEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          title: Artifacts::TITLE,
          type: Artifacts::TYPE,
          tags: Artifacts::TAGS.merge(description: "every tag it should carry, #{Helpers::Tags::FORMAT}"),
          body: Artifacts::BODY.merge(description: "the new body; a change adds a version"),
          note: Artifacts::NOTE.merge(description: "what the new body changes; kept only when the body changes"),
          **Memory::AUTHOR,
        },
        required: %w[id agent model],
      }.freeze

      include Deps[update_artifact: "agents.operations.update_artifact"]

      def handle(id:, **fields)
        artifact = artifact_queries.by_id(id)
        return missing("artifact", id) if artifact.nil?

        params = current(artifact).merge(fields)

        settled(update_artifact.call(id, params), id) { replied(it) }
      end

      private

      def current(artifact)
        { title: artifact.title, type: artifact.type, tags: artifact.tags.map(&:name),
          body: artifact_queries.version_row(artifact.id, artifact.version).body }
      end
    end
  end
end
