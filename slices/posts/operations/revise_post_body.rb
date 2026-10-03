# frozen_string_literal: true

module Posts
  module Operations
    class RevisePostBody
      include Deps[claim_post_photos: "operations.claim_post_photos", post_repo: "repos.post_repo"]

      def call(id, body:)
        post_repo.update(id, body:).tap { claim_post_photos.call(it) }
      end
    end
  end
end
