# frozen_string_literal: true

require "nokogiri"

module Social
  module Webmentions
    class Source
      AUTHOR_SELECTORS = [".h-entry .p-author.h-card", ".h-entry .p-author", ".h-card"].freeze
      BRIDGY_HOSTS = %w[brid.gy www.brid.gy].freeze
      CONTENT_SELECTORS = [
        ".h-entry .p-summary", ".h-entry .e-content", ".h-entry .p-name", ".p-summary", ".e-content",
      ].freeze
      DEFAULT_TYPE = Blog::Types::WebmentionType["mention"]
      EXCERPT_LIMIT = 500
      LINK_SELECTOR = "a[href], link[href]"
      REL_AUTHOR_SELECTOR = "a[rel~='author'], link[rel~='author']"
      TYPES = {
        "u-in-reply-to" => Blog::Types::WebmentionType["reply"],
        "u-like-of" => Blog::Types::WebmentionType["like"],
        "u-repost-of" => Blog::Types::WebmentionType["repost"],
      }.freeze
      WORDLESS_TYPES = [Blog::Types::WebmentionType["like"], Blog::Types::WebmentionType["repost"]].freeze

      def self.bridgy?(url) = BRIDGY_HOSTS.include?(Blog::Types::Normalized::Host.call(url) { nil })

      def self.truncate(text) = Blog::Truncation.fit(text, limit: EXCERPT_LIMIT)

      def initialize(url:, target:, html:)
        @url = url
        @target = target
        @document = Nokogiri::HTML5.parse(html.to_s)
      end

      def author
        node = AUTHOR_SELECTORS.lazy.filter_map { @document.at_css(it) }.first || @document.at_css(REL_AUTHOR_SELECTOR)
        return { name: nil, url: origin } unless node

        { name: card_name(node), url: normalize(card_href(node)) || origin }
      end

      def excerpt
        return nil if WORDLESS_TYPES.include?(type)

        text = CONTENT_SELECTORS.lazy.filter_map { @document.at_css(it) }.first
        truncate(Blog::Whitespace.squish(text.text)) if text
      end

      def links_to? = @document.css(LINK_SELECTOR).any? { matches_target?(it["href"]) }

      def type = @type ||= TYPES.find { |property, _| claims_target?(property) }&.last || DEFAULT_TYPE

      private

      def card_href(node) = node.at_css(".u-url")&.[]("href") || node["href"]

      def card_name(node) = truncate(Blog::Whitespace.squish(node.at_css(".p-name")&.text || node.text))

      def claims_target?(property)
        @document.css(".#{property}").any? { matches_target?(it["href"] || it["value"] || it.text) }
      end

      def matches_target?(href) = !target_url.nil? && normalize(href) == target_url

      def normalize(href)
        value = href.to_s.strip
        return nil if value.empty?

        Blog::Types::Normalized::Url.call(URI.join(@url, value).to_s) { nil }
      rescue URI::Error, ArgumentError
        nil
      end

      def origin = normalize("/")

      def target_url = @target_url ||= normalize(@target)

      def truncate(text)
        return nil if text.empty?

        self.class.truncate(text)
      end
    end
  end
end
