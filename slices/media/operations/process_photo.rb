# frozen_string_literal: true

require "vips"

module Media
  module Operations
    class ProcessPhoto
      ALL_PAGES = "n=-1"
      ANIMATED = %w[gif webp].map { Blog::Types::PhotoType[it] }.freeze
      FIRST_PAGE = ""
      LONG_EDGE = 2560
      LOSSY = %w[jpg webp].map { Blog::Types::PhotoType[it] }.freeze
      MAX_PIXELS = 100_000_000
      PAGE_HEIGHT = "page-height"
      QUALITY = 85

      Processed = Data.define(:body, :width, :height)

      def call(bytes, type)
        image = Vips::Image.thumbnail_buffer(
          bytes, LONG_EDGE, height: LONG_EDGE, size: :down, option_string: load_options(type),
        )

        Processed.new(body: save(image, type), width: image.width, height: frame_height(image))
      rescue Vips::Error
        nil
      end

      def pixels(bytes, type)
        image = Vips::Image.new_from_buffer(bytes, load_options(type))

        image.width * image.height
      rescue Vips::Error
        nil
      end

      private

      def frame_height(image)
        image.get_typeof(PAGE_HEIGHT).zero? ? image.height : image.get(PAGE_HEIGHT)
      end

      def load_options(type) = ANIMATED.include?(type) ? ALL_PAGES : FIRST_PAGE

      def save(image, type)
        options = LOSSY.include?(type) ? { Q: QUALITY } : Blog::Constants::EMPTY_HASH
        image.write_to_buffer(".#{type}", strip: true, **options)
      end
    end
  end
end
