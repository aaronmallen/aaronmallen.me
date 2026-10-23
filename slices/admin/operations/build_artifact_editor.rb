# frozen_string_literal: true

module Admin
  module Operations
    class BuildArtifactEditor
      include Blog::Constants

      FIELDS = %i[title type tags body note].freeze
      PLAN = Blog::Types::ArtifactType["plan"]
      KIND = Blog::Types::RecordKind["artifact"]

      include Deps[artifact_queries: "agents.repos.artifact_queries", tag_queries: "tags.repos.tag_queries"]

      def call(artifact: nil, params: nil, errors: EMPTY_HASH)
        { artifact:, values: params ? from_params(params) : from_artifact(artifact), errors:,
          choices: choices(artifact) }
      end

      private

      def choices(artifact) = (tag_queries.project_choices(KIND, artifact.id) if artifact)

      def from_artifact(artifact)
        return { **FIELDS.to_h { [it, EMPTY_STRING] }, type: PLAN } unless artifact

        { title: artifact.title, type: artifact.type, tags: Blog::Types::TagField[artifact.tags],
          body: artifact_queries.version_row(artifact.id, artifact.version).body, note: EMPTY_STRING }
      end

      def from_params(params) = FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }
    end
  end
end
