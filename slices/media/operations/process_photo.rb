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
      SHRINK = 0.8
      WIDTHS = [640, 1280, 1920].freeze

      Processed = Data.define(:body, :width, :height, :variants)

      def call(bytes, type)
        image = thumbnail(bytes, LONG_EDGE, type).copy_memory
        variants = resize(image, type)

        Processed.new(body: save(image, type), width: image.width, height: frame_height(image), variants:)
      rescue Vips::Error
        nil
      end

      def fit(bytes, content_type, max_bytes)
        type = Blog::Types::PhotoType.mapping.key(content_type)
        first = Vips::Image.new_from_buffer(bytes, FIRST_PAGE)
        edge = [first.width, first.height].max * Math.sqrt(max_bytes.fdiv(bytes.bytesize))

        until edge < 1
          body = save(thumbnail(bytes, edge.floor, type), type)
          return body if body.bytesize <= max_bytes

          edge *= SHRINK
        end
      rescue Vips::Error
        nil
      end

      def pixels(bytes, type)
        image = Vips::Image.new_from_buffer(bytes, load_options(type))

        image.width * image.height
      rescue Vips::Error
        nil
      end

      def preview(bytes, type, edge)
        save(thumbnail(bytes, edge, type), type)
      rescue Vips::Error
        nil
      end

      private

      def frame_height(image)
        image.get_typeof(PAGE_HEIGHT).zero? ? image.height : image.get(PAGE_HEIGHT)
      end

      def load_options(type) = ANIMATED.include?(type) ? ALL_PAGES : FIRST_PAGE

      def resize(image, type)
        WIDTHS.select { it < image.width }.to_h { [it, save(shrink(image, it), type)] }
      end

      def save(image, type)
        options = LOSSY.include?(type) ? { Q: QUALITY } : Blog::Constants::EMPTY_HASH
        image.write_to_buffer(".#{type}", strip: true, **options)
      end

      def scale(image, hscale, vscale)
        return image.resize(hscale, vscale:) unless image.has_alpha?

        image.premultiply.resize(hscale, vscale:).unpremultiply.cast(image.format)
      end

      def shrink(image, width)
        page = frame_height(image)
        pages = image.height / page
        height = [(page * width.fdiv(image.width)).round, 1].max
        small = scale(image, width.fdiv(image.width), (height * pages).fdiv(image.height))
        return small if small.get_typeof(PAGE_HEIGHT).zero?

        small.mutate { it.set_type!(GObject::GINT_TYPE, PAGE_HEIGHT, height) }
      end

      def thumbnail(bytes, width, type)
        Vips::Image.thumbnail_buffer(bytes, width, height: width, size: :down, option_string: load_options(type))
      end
    end
  end
end
