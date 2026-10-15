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

      def again(post_id, url: nil, at: Time.now)
        post = post_queries.published_body(post_id)
        check(post, at, only: url) if post
      end

      def call(at: Time.now)
        link_check_mutations.forget_unpublished
        post_queries.published_bodies.each { check(it, at) }
      end

      def links(body)
        anchors(body).each_with_object({}) do |anchor, found|
          url = outbound(anchor["href"])
          found[url] ||= anchor.text.strip if url
        end
      end

      private

      def anchors(body) = Nokogiri::HTML5.parse(Markdown.to_html(body)).css(LINK_SELECTOR)

      def check(post, at, only: nil)
        urls = links(post.body).keys
        link_check_mutations.forget_unlinked(post.id, urls)
        (only ? urls & [only] : urls).each { record(post, it, at) }
      end

      def host(url) = Blog::Types::Normalized::Host.call(url) { Blog::Constants::EMPTY_STRING }

      def outbound(href)
        uri = URI.join(site, href.to_s.strip)
        found = host(uri.to_s)
        return unless LINK_SCHEMES.include?(uri.scheme) && !found.empty? && found != host(site)

        uri.fragment = nil
        uri.to_s
      rescue URI::Error, ArgumentError
        nil
      end

      def record(post, url, at) = link_check_mutations.record(post_id: post.id, url:, reason: check_link.call(url), at:)

      def site = settings.site[:url].to_s
    end
  end
end
