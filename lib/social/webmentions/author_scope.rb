# frozen_string_literal: true

module Social
  module Webmentions
    class AuthorScope
      DOT_SEGMENTS = %w[. ..].freeze

      def initialize(author_url, single_author_hosts:)
        @author = parse(author_url)
        @author_segments = @author && segments(@author)
        @single_author_hosts = single_author_hosts
      end

      def covers?(url)
        page = parse(url)
        return false unless @author_segments && page && origin(page) == origin(@author)

        page_segments = segments(page)
        return false unless page_segments
        return @single_author_hosts.include?(host(@author)) if @author_segments.empty?

        page_segments.first(@author_segments.size) == @author_segments
      end

      private

      def host(uri) = Blog::Types::Normalized::Host.call(uri.to_s) { nil }

      def origin(uri) = [uri.scheme, host(uri), uri.port]

      def parse(url)
        uri = URI.parse(Blog::Types::Normalized::Url.call(url.to_s) { nil }.to_s)
        uri if uri.is_a?(URI::HTTP) && host(uri)
      rescue URI::Error
        nil
      end

      def segments(uri)
        found = URI::RFC2396_PARSER.unescape(uri.path).b.split("/").reject(&:empty?)
        found unless found.intersect?(DOT_SEGMENTS)
      end
    end
  end
end
