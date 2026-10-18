# frozen_string_literal: true

module API
  module Endpoints
    class CreateArtifact < ArtifactEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          title: Artifacts::TITLE,
          type: Artifacts::TYPE,
          tags: Artifacts::TAGS,
          body: Artifacts::BODY,
          note: Artifacts::NOTE,
          **Memory::AUTHOR,
        },
        required: %w[title type body],
      }.freeze

      include Deps[create_artifact: "agents.operations.create_artifact"]

      def handle(tags: [], **fields)
        settled(create_artifact.call(tags: Blog::Types::TagField[tags], **fields), nil) { replied(it) }
      end
    end
  end
end
