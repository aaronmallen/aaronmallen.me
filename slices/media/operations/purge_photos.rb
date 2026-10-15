# frozen_string_literal: true

module Media
  module Operations
    class PurgePhotos
      include Deps[client: "media_store.client", photo_mutations: "repos.photo_mutations"]

      def call(photos) = photos.count { purge(it) }

      private

      def purge(photo)
        photo_mutations.transaction do
          deleted = photo_mutations.delete_unclaimed(photo.id).positive?
          [photo.key, *photo.widths.map { photo.variant_key(it) }].each { client.delete(it) } if deleted
          deleted
        end
      rescue ObjectStore::Client::Error
        false
      end
    end
  end
end
