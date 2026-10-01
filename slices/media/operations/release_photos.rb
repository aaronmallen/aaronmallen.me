# frozen_string_literal: true

module Media
  module Operations
    class ReleasePhotos
      include Deps[photo_repo: "repos.photo_repo", purge_photos: "operations.purge_photos"]

      def call(owner, owner_ids)
        released = photo_repo.release(Blog::Types::PhotoOwner[owner], Array(owner_ids))
        photo_repo.after_commit { purge_photos.call(released) } unless released.empty?

        released
      end
    end
  end
end
