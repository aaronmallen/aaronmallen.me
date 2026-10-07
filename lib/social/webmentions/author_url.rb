# frozen_string_literal: true

module Social
  module Webmentions
    module AuthorUrl
      BARE_HOST = %r{\A(https?://[^/?#]+)\z}

      def self.normalize(url) = Blog::Types::Normalized::Url.call(url) { url }.sub(BARE_HOST, '\\1/')
    end
  end
end
