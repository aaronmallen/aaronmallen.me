# frozen_string_literal: true

require "nokogiri"

module Posts
  module Operations
    class CheckPostLinks
      LINK_SCHEMES = %w[http https].freeze
      LINK_SELECTOR = "a[href]"

      include Deps[
        "operations.check_link",
        "settings",
        link_check_mutations: "repos.post_link_check_mutations",
        post_queries: "repos.post_queries",
      ]

      def again(post_id, url: nil, at: Time.now)
        post = post_queries.published_body(post_id)
        return unless post

        urls = links(post.body_html).keys
        link_check_mutations.forget_unlinked(post.id, urls)
        (url ? urls & [url] : urls).each { record([post.id], it, at) }
      end

      def call(at: Time.now, &checked)
        link_check_mutations.forget_unpublished
        linked = urls_by_post
        linked.each { link_check_mutations.forget_unlinked(*it) }
        posts_by_url(linked).each do |url, post_ids|
          record(post_ids, url, at)
          checked&.call
        end
      end

      def due = urls_by_post.values.reduce([], :|).size

      def links(html)
        anchors(html).each_with_object({}) do |anchor, found|
          url = outbound(anchor["href"])
          found[url] ||= anchor.text.strip if url
        end
      end

      private

      def anchors(html) = Nokogiri::HTML5.parse(html).css(LINK_SELECTOR)

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

      def posts_by_url(linked)
        linked.each_with_object({}) { |(id, urls), found| urls.each { (found[it] ||= []) << id } }
      end

      def record(post_ids, url, at)
        reason = check_link.call(url)
        post_ids.each { link_check_mutations.record(post_id: it, url:, reason:, at:) }
      end

      def site = settings.site[:url].to_s

      def urls_by_post = post_queries.published_bodies.to_h { [it.id, links(it.body_html).keys] }
    end
  end
end
