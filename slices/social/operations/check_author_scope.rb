# frozen_string_literal: true

module Social
  module Operations
    class CheckAuthorScope
      DOT_SEGMENTS = %w[. ..].freeze

      def call(author_url, urls, single_author_hosts:)
        author = parse(author_url)
        author_segments = author && segments(author)
        return false unless author_segments

        urls.all? { covers?(author, author_segments, it, single_author_hosts) }
      end

      private

      def covers?(author, author_segments, url, single_author_hosts)
        page = parse(url)
        return false unless page && origin(page) == origin(author)

        page_segments = segments(page)
        return false unless page_segments
        return single_author_hosts.include?(host(author)) if author_segments.empty?

        page_segments.first(author_segments.size) == author_segments
      end

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
