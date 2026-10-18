# frozen_string_literal: true

module Agents
  module Relations
    class Artifacts < Blog::DB::Relation
      TAGS = Sequel.function(:array_to_string, :tags, " ")

      schema :artifacts, infer: true

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

        where(Sequel.|(Sequel.ilike(:title, pattern), Sequel.ilike(TAGS, pattern), { id: bodies }))
      end

      def recently_updated = order(self[:updated_at].desc, self[:id].desc)
    end
  end
end
