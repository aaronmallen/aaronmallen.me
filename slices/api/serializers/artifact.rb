# frozen_string_literal: true

module API
  module Serializers
    class Artifact < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: { type: "integer", description: "the artifact's number, shown as #N" },
          title: { type: "string", description: "its title; marked untrusted when an agent set it" },
          type: { type: "string", enum: Blog::Types::ArtifactType.values },
          tags: Helpers::Schema::TAGS,
          version: { type: "integer", description: "the number of its latest version" },
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at

      def tags(artifact) = artifact.tags.map(&:name)

      def title(artifact) = artifact.title_by_agent? ? untrusted(artifact.title) : artifact.title
    end
  end
end
