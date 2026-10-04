# frozen_string_literal: true

module Posts
  module Relations
    class PostTagRemovals < Blog::DB::Relation
      schema :post_tag_removals, infer: true

      def last_removed_at = unordered.max(:removed_at)
    end
  end
end
