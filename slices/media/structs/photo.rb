# frozen_string_literal: true

module Media
  module Structs
    class Photo < Blog::DB::Struct
      def path = "#{Blog::Constants::MEDIA_PATH}#{key}"
    end
  end
end
