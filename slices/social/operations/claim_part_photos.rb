# frozen_string_literal: true

module Social
  module Operations
    class ClaimPartPhotos
      PHOTO_OWNER = Blog::Types::PhotoOwner["social_post_part"]

      include Deps[
        claim_photo_keys: "media.operations.claim_photo_keys",
        release_photos: "media.operations.release_photos",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(social_post_id, held_before = Blog::Constants::EMPTY_ARRAY)
        held = social_post_queries.part_photo_keys(social_post_id)
        gone = held_before - held.keys

        release_photos.call(PHOTO_OWNER, gone) unless gone.empty?
        held.each { |part_id, keys| claim_photo_keys.call(PHOTO_OWNER, part_id, keys) }
      end
    end
  end
end
