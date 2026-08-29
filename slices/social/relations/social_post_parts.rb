# frozen_string_literal: true

module Social
  module Relations
    class SocialPostParts < Blog::DB::Relation
      schema :social_post_parts, infer: true

      def for_social_post(social_post_id) = where(social_post_id:)

      def in_order = order(self[:position].asc)
    end
  end
end
