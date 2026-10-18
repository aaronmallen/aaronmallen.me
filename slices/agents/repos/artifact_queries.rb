# frozen_string_literal: true

module Agents
  module Repos
    class ArtifactQueries < Blog::DB::Repo
      def by_id(id) = artifacts.by_pk(id).one

      def listed(page, type: nil, text: nil)
        found = type ? artifacts.where(type:) : artifacts
        found = found.matching(text) if text

        page.fill(found.recently_updated.paged(page).to_a)
      end

      def version(artifact_id, number) = artifact_versions.where(artifact_id:, number:).one

      def versions(artifact_id) = artifact_versions.where(artifact_id:).listed.to_a
    end
  end
end
