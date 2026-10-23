# frozen_string_literal: true

module Agents
  module Relations
    class Artifacts < Blog::DB::Relation
      schema :artifacts, infer: true do
        associations do
          has_many :artifact_tags
          has_many :tags, through: :artifact_tags, view: :in_name_order
        end
      end

      def latest_version_first
        current = { artifact_id: self[:id].qualified, number: self[:version].qualified }
        latest = artifact_versions.dataset.unordered.where(current).select(:created_at)

        order(Sequel.desc(latest), self[:id].desc)
      end

      def linkable = linkables(title: :title, day: self.class.site_day(:created_at))

      def matching(text)
        return none if unmatchable?(text)

        pattern = like_pattern(text)
        bodies = artifact_versions.current.where(Sequel.ilike(:body, pattern)).dataset.unordered.select(:artifact_id)

        where(Sequel.|(Sequel.ilike(:title, pattern), { id: tagged(pattern) }, { id: bodies }))
      end

      def recently_updated = order(self[:updated_at].desc, self[:id].desc)

      private

      def tagged(pattern)
        named = Sequel.ilike(Blog::DB::Plugins::Taggings::NAME, pattern)

        artifact_tags.dataset.unordered.join(:tags, id: :tag_id).where(named).select(:artifact_id)
      end
    end
  end
end
