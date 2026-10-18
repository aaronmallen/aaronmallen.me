# frozen_string_literal: true

module Agents
  module Repos
    class ArtifactMutations < Blog::DB::Repo
      root :artifacts

      stamped_commands :create, :update
      commands delete: :by_pk

      def add_version(artifact_id, **) = artifact_versions.command(:create).call(artifact_id:, **)

      def by_id_for_update(id) = artifacts.by_pk(id).lock.one
    end
  end
end
