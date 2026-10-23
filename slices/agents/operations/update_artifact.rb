# frozen_string_literal: true

module Agents
  module Operations
    class UpdateArtifact < Blog::Operation
      include SessionWrite
      include Deps[
        artifact_mutations: "repos.artifact_mutations",
        artifact_queries: "repos.artifact_queries",
        contract: "contracts.artifact_contract",
        touch_session: "operations.touch_session",
      ]

      def call(id, params)
        fields = step validate(params)
        step touch(fields)

        transaction do
          artifact = step found(artifact_mutations.by_id_for_update(id))
          rewrite(artifact, fields)
          revise(artifact, **fields.slice(:body, :note, :agent, :model, :session_id))
          artifact_queries.by_id(id)
        end
      end

      private

      def retitled(artifact, title:, agent:, model:, **)
        artifact.title == title ? {} : { title:, title_agent: agent, title_model: model }
      end

      def revise(artifact, body:, **)
        return if artifact_queries.version_row(artifact.id, artifact.version).body == body

        artifact_mutations.add_version(artifact.id, body:, **)
      end

      def rewrite(artifact, fields)
        artifact_mutations.update(artifact.id, { type: fields[:type], **retitled(artifact, **fields) })
        artifact_mutations.replace_tags(artifact.id, fields[:tags])
      end
    end
  end
end
