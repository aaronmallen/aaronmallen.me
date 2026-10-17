# frozen_string_literal: true

module Social
  module Relations
    class SocialPostParts < Blog::DB::Relation
      KEY = %i[social_post_id position].freeze

      schema :social_post_parts, infer: true do
        associations do
          has_many :social_post_photos, as: :photos, view: :in_order
        end
      end

      def for_social_post(social_post_id) = where(social_post_id:)

      def in_order = order(self[:position].asc)

      def write(social_post_id, bodies, now: Time.now)
        for_social_post(social_post_id).exclude(position: 1..bodies.size).delete
        rows = bodies.each.with_index(1).map do |body, position|
          { social_post_id:, position:, body:, created_at: now, updated_at: now }
        end

        dataset.insert_conflict(target: KEY, update: excluded(%i[body updated_at])).multi_insert(rows)
      end
    end
  end
end
