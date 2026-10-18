# frozen_string_literal: true

module Agents
  module Operations
    class CreateArtifact < Blog::Operation
      include SessionWrite
      include Deps[
        artifact_mutations: "repos.artifact_mutations",
        artifact_queries: "repos.artifact_queries",
        contract: "contracts.artifact_contract",
        touch_session: "operations.touch_session",
      ]

      def call(params)
        fields = step validate(params)
        step touch(fields)

        transaction do
          id = artifact_mutations.create(
            **fields.slice(:title, :type, :tags), title_agent: fields[:agent], title_model: fields[:model],
          ).id
          artifact_mutations.add_version(id, **fields.slice(:body, :note, :agent, :model, :session_id))
          artifact_queries.by_id(id)
        end
      end
    end
  end
end
