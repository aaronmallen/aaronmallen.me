# frozen_string_literal: true

module Social
  module Operations
    class DeleteSocialPost < Blog::Operation
      PHOTO_OWNER = ClaimPartPhotos::PHOTO_OWNER

      include Deps[
        release_photos: "media.operations.release_photos",
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(id)
        transaction do
          held = social_post_queries.part_photo_keys(id).keys
          count = social_post_mutations.delete_unposted(id)
          release_photos.call(PHOTO_OWNER, held) if count.positive? && held.any?
          step removed(id, count)
        end
      end

      private

      def removed(id, count)
        return Success(id) if count.positive?

        social_post_queries.claimed?(id) ? Failure(:already_posted) : Failure(:not_found)
      end
    end
  end
end
