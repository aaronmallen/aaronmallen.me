# frozen_string_literal: true

module Agents
  module Repos
    class ArtifactQueries < Blog::DB::Repo
      def by_id(id) = artifacts.by_pk(id).one

      def count_by_type = artifacts.tally(:type, Blog::Types::ArtifactType.values)

      def current_versions(ids) = artifact_versions.current.where(artifact_id: ids).to_a.to_h { [it.artifact_id, it] }

      def latest_listed(page, **) = page.fill(found(**).latest_version_first.paged(page).to_a)

      def listed(page, **) = page.fill(found(**).recently_updated.paged(page).to_a)

      def updated_since(time) = artifacts.where(artifacts[:updated_at] >= time).count

      def version(artifact_id, number) = artifact_versions.where(artifact_id:, number:).one

      def versions(artifact_id) = artifact_versions.where(artifact_id:).listed.to_a

      private

      def found(type: nil, text: nil)
        found = type ? artifacts.where(type:) : artifacts
        text ? found.matching(text) : found
      end
    end
  end
end
