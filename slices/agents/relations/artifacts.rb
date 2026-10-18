# frozen_string_literal: true

module Agents
  module Relations
    class Artifacts < Blog::DB::Relation
      TAGS = Sequel.function(:array_to_string, :tags, " ")

      schema :artifacts, infer: true

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
