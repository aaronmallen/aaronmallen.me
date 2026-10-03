# frozen_string_literal: true

module Social
  module Relations
    class HeldWebmentions < Blog::DB::Relation
      schema :held_webmentions, infer: true

      def hold(post_id:, source_url:, target_url:)
        dataset.insert_conflict.insert(post_id:, source_url:, target_url:)
      end

      def oldest_first = order(self[:id].asc)
    end
  end
end
