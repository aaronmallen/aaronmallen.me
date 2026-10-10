# frozen_string_literal: true

module Social
  module Operations
    class NormalizeAuthorUrl
      BARE_HOST = %r{\A(https?://[^/?#]+)\z}

      def call(url) = Blog::Types::Normalized::Url.call(url) { url }.sub(BARE_HOST, '\\1/')
    end
  end
end
