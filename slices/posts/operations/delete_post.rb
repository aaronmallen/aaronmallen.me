# frozen_string_literal: true

module Posts
  module Operations
    class DeletePost < Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["post"]

      include Deps[post_mutations: "repos.post_mutations", release_photos: "media.operations.release_photos"]

      def call(id)
        transaction do
          post = step found(post_mutations.delete(id))
          release_photos.call(PHOTO_OWNER, post.id)
          post
        end
      end
    end
  end
end
