# frozen_string_literal: true

require "vips"

module LinkedIn
  module Images
    JPEG = "image/jpeg"
    MAX = 4
    PUT = "PUT image upload"
    QUALITY = 85
    START_PATH = "/rest/images?action=initializeUpload"
    START = "POST #{START_PATH}".freeze
    TAKES = %w[image/gif image/jpeg image/png].freeze
    WHITE = 255

    def self.content(photos, owner, connection, &request)
      return if photos.empty?

      images = photos.first(MAX).map do |photo|
        alt = photo.alt.to_s.strip
        id = upload(connection, owner, *fit(photo.body, photo.content_type), request)

        { altText: (alt unless alt.empty?), id: }.compact
      end

      images.one? ? { media: images.first } : { multiImage: { images: } }
    end

    def self.fit(body, type)
      return [body, type] if TAKES.include?(type)

      image = Vips::Image.new_from_buffer(body, "")
      image = image.flatten(background: WHITE) if image.has_alpha?

      [image.write_to_buffer(".jpg", Q: QUALITY, strip: true), JPEG]
    end
    private_class_method :fit

    def self.upload(connection, owner, body, type, request)
      started = request.call(START, -> { connection.post(START_PATH, initializeUploadRequest: { owner: }) })
      value = started.body.is_a?(Hash) ? started.body["value"].to_h : Blog::Constants::EMPTY_HASH
      image, url = value.values_at("image", "uploadUrl")
      raise Error, "LinkedIn answered #{START} without an image and an upload URL" unless image && url

      request.call(PUT, -> { connection.put(url, body) { it.headers["Content-Type"] = type } })
      image
    end
    private_class_method :upload
  end
end
