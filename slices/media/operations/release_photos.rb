# frozen_string_literal: true

module Media
  module Operations
    class ReleasePhotos
      include Deps[photo_mutations: "repos.photo_mutations", purge_photos: "operations.purge_photos"]

      def call(owner, owner_ids)
        released = photo_mutations.release(Blog::Types::PhotoOwner[owner], Array(owner_ids))
        photo_mutations.after_commit { purge_photos.call(released) } unless released.empty?

        released
      end
    end
  end
end
