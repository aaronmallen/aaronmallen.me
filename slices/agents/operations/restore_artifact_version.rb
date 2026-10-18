# frozen_string_literal: true

module Agents
  module Operations
    class RestoreArtifactVersion < Blog::Operation
      RESTORED = "Restored version %d"

      include Deps[
        artifact_mutations: "repos.artifact_mutations",
        artifact_queries: "repos.artifact_queries",
        contract: "contracts.artifact_version_contract",
      ]

      def call(id, number, params)
        fields = step validate(params)

        transaction do
          step found(artifact_mutations.by_id_for_update(id))
          copy(step(found(artifact_mutations.version(id, number))), **fields)
          artifact_queries.by_id(id)
        end
      end

      private

      def copy(version, note:, **author)
        artifact_mutations.add_version(
          version.artifact_id, body: version.body, note: note || format(RESTORED, version.number), **author,
        )
      end
    end
  end
end
