# frozen_string_literal: true

require "nokogiri"

module Posts
  module Operations
    class CheckPostLinks
      LINK_SCHEMES = %w[http https].freeze
      LINK_SELECTOR = "a[href]"

      include Deps[
        "settings",
        check_link: "social.operations.check_link",
        link_check_mutations: "repos.post_link_check_mutations",
        post_queries: "repos.post_queries",
      ]

      def call(at: Time.now)
        link_check_mutations.forget_unpublished
        post_queries.published.each { check(it, at) }
      end

      private

      def check(post, at)
        urls = links_in(post.body)
        link_check_mutations.forget_unlinked(post.id, urls)
        urls.each { link_check_mutations.record(post_id: post.id, url: it, reason: check_link.call(it), at:) }
      end

      def host(url) = Blog::Types::Normalized::Host.call(url) { Blog::Constants::EMPTY_STRING }

      def links_in(body)
        Nokogiri::HTML5.parse(Markdown.to_html(body)).css(LINK_SELECTOR).filter_map { outbound(it["href"]) }.uniq
      end

      def outbound(href)
        uri = URI.join(site, href.to_s.strip)
        found = host(uri.to_s)
        return unless LINK_SCHEMES.include?(uri.scheme) && !found.empty? && found != host(site)

        uri.fragment = nil
        uri.to_s
      rescue URI::Error, ArgumentError
        nil
      end

      def site = settings.site[:url].to_s
    end
  end
end
