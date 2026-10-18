# frozen_string_literal: true

require "nokogiri"

module PageFetcher
  module Page
    HTML = "html"
    TITLE = "meta[property='og:title']"

    def self.document(response) = (Nokogiri::HTML5.parse(response.body) if html?(response))

    def self.html?(response) = response.success? && response.media_type.include?(HTML)

    def self.text(value) = Blog::Helpers::Whitespace.squish(value.to_s.gsub(/[[:cntrl:]]/, " "))

    def self.title(document)
      [document.at_css(TITLE)&.[]("content"), document.at_css("title")&.text].lazy.map { text(it) }.find { !it.empty? }
    end
  end
end
