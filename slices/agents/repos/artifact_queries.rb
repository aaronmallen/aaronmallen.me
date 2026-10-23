# frozen_string_literal: true

module Agents
  module Repos
    class ArtifactQueries < Blog::DB::Repo
      def by_id(id) = artifacts.combine(:tags).by_pk(id).one

      def count_by_type = artifacts.tally(:type, Blog::Types::ArtifactType.values)

      def current_versions(ids)
        artifact_versions.current_listed.where(artifact_id: ids).to_a.to_h { [it.artifact_id, it] }
      end

      def latest_listed(page, **) = page.fill(found(**).latest_version_first.paged(page).to_a)

      def listed(page, **) = page.fill(found(**).recently_updated.paged(page).to_a)

      def page_by_tag(tag_ids, page)
        page.fill(artifacts.carrying(:artifact_tags, tag_ids).recently_updated.paged(page).to_a)
      end

      def updated_since(time) = artifacts.where(artifacts[:updated_at] >= time).count

      def version_row(artifact_id, number) = artifact_versions.where(artifact_id:, number:).one

      def versions(artifact_id) = artifact_versions.where(artifact_id:).listed.to_a

      private

      def found(type: nil, text: nil)
        found = type ? artifacts.combine(:tags).where(type:) : artifacts.combine(:tags)
        text ? found.matching(text) : found
      end
    end
  end
end
