# frozen_string_literal: true

module Shares
  module Operations
    class StorePreview
      EDGE = 1280

      include Deps[
        client: "share_store.client",
        detect_photo_type: "media.operations.detect_photo_type",
        processor: "media.operations.process_photo",
      ]

      def call(file)
        file.rewind
        type = detect_photo_type.call(file)
        return unless type

        body = shrink(file.read, type)
        file.rewind
        body && client.put(ObjectStore::Key.generate, body, content_type: Blog::Types::PhotoType.mapping.fetch(type))
      rescue ObjectStore::Client::Error
        nil
      end

      private

      def shrink(bytes, type)
        pixels = processor.pixels(bytes, type)
        processor.preview(bytes, type, EDGE) if pixels && pixels <= Media::Operations::ProcessPhoto::MAX_PIXELS
      end
    end
  end
end
