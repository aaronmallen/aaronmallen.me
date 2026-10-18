# frozen_string_literal: true

module Agents
  module Operations
    class DeleteArtifact < Blog::Operation
      include Deps[artifact_mutations: "repos.artifact_mutations"]

      def call(id) = step found(artifact_mutations.delete(id))
    end
  end
end
