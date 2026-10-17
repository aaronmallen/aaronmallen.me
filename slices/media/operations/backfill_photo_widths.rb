# frozen_string_literal: true

module Media
  module Operations
    class BackfillPhotoWidths
      include Deps[
        client: "media_store.client",
        photo_mutations: "repos.photo_mutations",
        photo_queries: "repos.photo_queries",
        processor: "operations.process_photo",
      ]

      def call = photo_queries.missing_widths.count { backfill(it) }

      private

      def backfill(photo)
        stored = client.get(photo.key)
        variants = stored && processor.variants(stored.body, photo.type)
        return false unless variants

        variants.each { |width, body| client.put(photo.variant_key(width), body, content_type: stored.content_type) }
        photo_mutations.update(photo.id, widths: variants.keys)
        true
      rescue ObjectStore::Client::Error
        false
      end
    end
  end
end
