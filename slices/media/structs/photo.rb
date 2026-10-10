# frozen_string_literal: true

module Media
  module Structs
    class Photo < Blog::DB::Struct
      def path = "#{Blog::Types::PHOTO_PATH}#{key}"

      def url = Hanami.app.settings.site_url(path)
    end
  end
end
