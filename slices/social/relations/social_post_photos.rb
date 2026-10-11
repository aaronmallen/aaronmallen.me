# frozen_string_literal: true

module Social
  module Relations
    class SocialPostPhotos < Blog::DB::Relation
      schema :social_post_photos, infer: true

      def for_parts(social_post_part_ids) = where(social_post_part_id: social_post_part_ids)

      def in_order = order(self[:position].asc)

      def write(part_ids, photos)
        for_parts(part_ids.values).delete
        rows = photos.group_by { it[:part] }.flat_map do |part, held|
          held.each.with_index(1).map do |photo, position|
            { social_post_part_id: part_ids.fetch(part), position:, photo_key: photo[:key], alt_text: photo[:alt] }
          end
        end

        command(:create, result: :many).call(rows) unless rows.empty?
      end
    end
  end
end
