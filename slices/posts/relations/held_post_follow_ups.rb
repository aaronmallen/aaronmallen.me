# frozen_string_literal: true

module Posts
  module Relations
    class HeldPostFollowUps < Blog::DB::Relation
      schema :held_post_follow_ups, infer: true

      def hold(post_id:, follow_up:, requested_at:)
        dataset.insert_conflict.insert(post_id:, follow_up:, requested_at:)
      end

      def oldest_first = order(self[:id].asc)
    end
  end
end
