# frozen_string_literal: true

module Posts
  module Relations
    class PostDeletions < Blog::DB::Relation
      schema :post_deletions, infer: true

      def last_deleted_at = unordered.max(:deleted_at)
    end
  end
end
