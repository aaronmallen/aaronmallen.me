# frozen_string_literal: true

module Posts
  module Relations
    class PostTags < Blog::DB::Relation
      include Blog::DB::Taggings

      schema :post_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end

      def owner_key = :post_id
    end
  end
end
