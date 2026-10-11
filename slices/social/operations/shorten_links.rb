# frozen_string_literal: true

module Social
  module Operations
    class ShortenLinks
      UNMADE = "x" * 5

      include Deps[
        "settings",
        scan_links: "operations.scan_links",
        short_link_queries: "shares.repos.short_link_queries",
        shorten_link: "shares.operations.shorten_link",
      ]

      def call(body, make:)
        scan_links.map(body) { shortens?(it) ? short(it, make) : it }
      end

      private

      def code(url, make)
        return shorten_link.call(url).fmap(&:code).value_or(nil) if make

        short_link_queries.by_destination(url)&.code || UNMADE
      end

      def host(url) = Blog::Types::Normalized::Host.call(url) { nil }

      def origin = settings.share_site[:url].chomp("/")

      def short(url, make)
        code = code(url, make)

        code ? "#{origin}/#{code}" : url
      end

      def shortens?(url)
        link_host = host(url)
        return false if link_host.nil? || link_host == host(settings.share_site[:url])

        Blog::Types::Url.valid?(url) && !settings.owns?(url)
      end
    end
  end
end
