# frozen_string_literal: true

module Decisions
  module Relations
    class DecisionTags < Blog::DB::Relation
      include Blog::DB::Taggings

      schema :decision_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end

      def owner_key = :decision_id
    end
  end
end
