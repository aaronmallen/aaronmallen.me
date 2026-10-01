# frozen_string_literal: true

module Media
  module Structs
    class Photo < Blog::DB::Struct
      def path = "/media/#{key}"

      def url = Blog::Site.url(path)
    end
  end
end
