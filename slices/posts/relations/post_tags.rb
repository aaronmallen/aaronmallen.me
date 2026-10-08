# frozen_string_literal: true

module Posts
  module Relations
    class PostTags < Blog::DB::Relation
      use :taggings, owner_key: :post_id

      schema :post_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
