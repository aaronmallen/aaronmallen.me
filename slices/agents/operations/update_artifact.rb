# frozen_string_literal: true

module Agents
  module Operations
    class UpdateArtifact < Blog::Operation
      include Deps[
        artifact_mutations: "repos.artifact_mutations",
        artifact_queries: "repos.artifact_queries",
        contract: "contracts.artifact_contract",
      ]

      def call(id, params)
        fields = step validate(params)

        transaction do
          artifact = step found(artifact_mutations.by_id_for_update(id))
          artifact_mutations.update(id, { **fields.slice(:type, :tags), **retitled(artifact, **fields) })
          revise(artifact, **fields.slice(:body, :note, :agent, :model))
          artifact_queries.by_id(id)
        end
      end

      private

      def retitled(artifact, title:, agent:, model:, **)
        artifact.title == title ? {} : { title:, title_agent: agent, title_model: model }
      end

      def revise(artifact, body:, **)
        return if artifact_mutations.version(artifact.id, artifact.version).body == body

        artifact_mutations.add_version(artifact.id, body:, **)
      end
    end
  end
end
