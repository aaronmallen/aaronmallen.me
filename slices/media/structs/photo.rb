# frozen_string_literal: true

module Media
  module Structs
    class Photo < Blog::DB::Struct
      def path = "#{Media::Types::PATH}#{key}"
    end
  end
end
