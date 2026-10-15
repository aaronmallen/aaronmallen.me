# frozen_string_literal: true

module Media
  module Structs
    class Photo < Blog::DB::Struct
      def path = "#{Blog::Constants::MEDIA_PATH}#{key}"

      def srcset
        [*widths.map { "#{Blog::Constants::MEDIA_PATH}#{variant_key(it)} #{it}w" }, "#{path} #{width}w"].join(", ")
      end

      def type = Blog::Types::PhotoType[File.extname(key).delete_prefix(".")]

      def variant_key(width) = "#{width}/#{key}"
    end
  end
end
