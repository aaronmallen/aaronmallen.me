# frozen_string_literal: true

module Posts
  module Relations
    class PostEdits < Blog::DB::Relation
      schema :post_edits, infer: true do
        associations do
          belongs_to :post
        end
      end

      def edited_at(post_ids)
        unordered.where(post_id: post_ids).select(:post_id) { time.max(updated_at).as(:edited_at) }.group(:post_id)
      end

      def for_post(post_id) = where(post_id:)

      def oldest_first = order(self[:created_at].asc, self[:id].asc)
    end
  end
end
