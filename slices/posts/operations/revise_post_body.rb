# frozen_string_literal: true

module Posts
  module Operations
    class RevisePostBody
      PHOTO_OWNER = Blog::Types::PhotoOwner["post"]

      include Deps[claim_photos: "media.operations.claim_photos", post_repo: "repos.post_repo"]

      def call(id, body:)
        post_repo.update(id, body:).tap { claim_photos.call(PHOTO_OWNER, id, it.body, it.og_image_url) }
      end
    end
  end
end
