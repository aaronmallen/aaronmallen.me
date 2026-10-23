# frozen_string_literal: true

module Agents
  module Repos
    class ArtifactMutations < Blog::DB::Repo
      root :artifacts

      stamped_commands :create, :update
      commands delete: :by_pk
      tagged_by :artifact_tags

      def add_version(artifact_id, **) = artifact_versions.command(:create).call(artifact_id:, **)
    end
  end
end
