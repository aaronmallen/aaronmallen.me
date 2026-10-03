# frozen_string_literal: true

module Posts
  module Operations
    class ClaimPostPhotos
      PHOTO_OWNER = Blog::Types::PhotoOwner["post"]

      include Deps[claim_photos: "media.operations.claim_photos", post_edit_repo: "repos.post_edit_repo"]

      def call(post)
        claim_photos.call(PHOTO_OWNER, post.id, post.body, post.og_image_url, *post_edit_repo.notes(post.id))
      end
    end
  end
end
