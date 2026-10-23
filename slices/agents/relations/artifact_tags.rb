# frozen_string_literal: true

module Agents
  module Relations
    class ArtifactTags < Blog::DB::Relation
      use :taggings

      schema :artifact_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
