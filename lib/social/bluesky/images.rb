# frozen_string_literal: true

require "vips"

module Social
  module Bluesky
    module Images
      EMBED = "app.bsky.embed.images"
      JPEG = "image/jpeg"
      MAX_BYTES = 1_000_000
      QUALITY = 85
      SHRINK = 0.8
      UPLOAD_BLOB = "com.atproto.repo.uploadBlob"
      WHITE = 255

      def self.blob(uploaded)
        uploaded["blob"] or raise Client::Error, "Bluesky returned no blob for an uploaded image"
      end
      private_class_method :blob

      def self.embed(photos)
        return if photos.empty?

        images = photos.map do |photo|
          { alt: photo.alt.to_s, aspectRatio: { height: photo.height, width: photo.width },
            image: blob(yield(*fit(photo.body, photo.content_type))) }
        end

        { "$type" => EMBED, images: }
      end

      def self.fit(body, type)
        return [body, type] if body.bytesize <= MAX_BYTES

        image = flat(Vips::Image.new_from_buffer(body, ""))
        scale = Math.sqrt(MAX_BYTES.fdiv(body.bytesize))

        loop do
          shrunk = image.resize(scale).write_to_buffer(".jpg", Q: QUALITY, strip: true)
          return [shrunk, JPEG] if shrunk.bytesize <= MAX_BYTES

          scale *= SHRINK
        end
      end
      private_class_method :fit

      def self.flat(image) = image.has_alpha? ? image.flatten(background: WHITE) : image
      private_class_method :flat
    end
  end
end
