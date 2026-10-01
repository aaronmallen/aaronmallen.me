# frozen_string_literal: true

module Posts
  module Operations
    class DeletePost < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["post"]

      include Deps[post_repo: "repos.post_repo", release_photos: "media.operations.release_photos"]

      def call(id)
        transaction do
          post = step deleted(post_repo.delete(id))
          release_photos.call(PHOTO_OWNER, post.id)
          post
        end
      end

      private

      def deleted(post) = post ? Success(post) : Failure(:not_found)
    end
  end
end
