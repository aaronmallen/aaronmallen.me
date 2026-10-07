# frozen_string_literal: true

module Media
  module Operations
    class PurgePhotos
      include Deps["store.client", photo_mutations: "repos.photo_mutations"]

      def call(photos) = photos.count { purge(it) }

      private

      def purge(photo)
        photo_mutations.transaction do
          deleted = photo_mutations.delete_unclaimed(photo.id).positive?
          client.delete(photo.key) if deleted
          deleted
        end
      rescue Store::Client::Error
        false
      end
    end
  end
end
