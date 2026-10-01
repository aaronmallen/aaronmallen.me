# frozen_string_literal: true

module Media
  module Operations
    class PurgePhotos
      include Deps["store.client", photo_repo: "repos.photo_repo"]

      def call(photos) = photos.count { purge(it) }

      private

      def purge(photo)
        photo_repo.transaction do
          deleted = photo_repo.delete_unclaimed(photo.id).positive?
          client.delete(photo.key) if deleted
          deleted
        end
      rescue Store::Client::Error
        false
      end
    end
  end
end
