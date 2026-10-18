# frozen_string_literal: true

module Blog
  module Helpers
    module MediaPath
      def self.for(key) = "#{Blog::Constants::MEDIA_PATH}#{key}"
    end
  end
end
