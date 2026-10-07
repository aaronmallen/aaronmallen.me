# frozen_string_literal: true

module Posts
  module Operations
    class ClaimPostPhotos
      PHOTO_OWNER = Blog::Types::PhotoOwner["post"]

      include Deps[claim_photos: "media.operations.claim_photos", post_queries: "repos.post_queries"]

      def call(post)
        claim_photos.call(PHOTO_OWNER, post.id, post.body, post.og_image_url, *post_queries.edit_notes(post.id))
      end
    end
  end
end
