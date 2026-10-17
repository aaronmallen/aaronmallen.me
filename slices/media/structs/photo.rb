# frozen_string_literal: true

module Media
  module Structs
    class Photo < Blog::DB::Struct
      def path = Helpers::MediaPath.for(key)

      def srcset
        [*widths.map { "#{Helpers::MediaPath.for(variant_key(it))} #{it}w" }, "#{path} #{width}w"].join(", ")
      end

      def type = Blog::Types::PhotoType[File.extname(key).delete_prefix(".")]

      def variant_key(width) = "#{width}/#{key}"
    end
  end
end
