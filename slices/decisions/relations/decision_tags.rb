# frozen_string_literal: true

module Decisions
  module Relations
    class DecisionTags < Blog::DB::Relation
      use :taggings

      schema :decision_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
