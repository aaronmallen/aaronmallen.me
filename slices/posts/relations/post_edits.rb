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

      def edited_at_by_post(post_ids)
        latest = edited_at(post_ids).dataset

        latest.db.from(latest).select { json_object_agg(post_id, edited_at) }
      end

      def for_post(post_id) = where(post_id:)

      def for_posts(post_ids) = where(post_id: post_ids)
    end
  end
end
