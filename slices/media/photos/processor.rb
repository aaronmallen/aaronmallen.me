# frozen_string_literal: true

require "vips"

module Media
  module Photos
    class Processor
      LONG_EDGE = 2560
      MAX_PIXELS = 100_000_000
      PAGE_HEIGHT = "page-height"

      Processed = Data.define(:body, :width, :height)

      def call(bytes, type)
        image = Vips::Image.thumbnail_buffer(
          bytes, LONG_EDGE, height: LONG_EDGE, size: :down, option_string: type.load_options,
        )

        Processed.new(body: save(image, type), width: image.width, height: frame_height(image))
      rescue Vips::Error
        nil
      end

      def pixels(bytes, type)
        image = Vips::Image.new_from_buffer(bytes, type.load_options)

        image.width * image.height
      rescue Vips::Error
        nil
      end

      private

      def frame_height(image)
        image.get_typeof(PAGE_HEIGHT).zero? ? image.height : image.get(PAGE_HEIGHT)
      end

      def save(image, type) = image.write_to_buffer(".#{type.extension}", strip: true, **type.save_options)
    end
  end
end
