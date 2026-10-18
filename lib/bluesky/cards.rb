# frozen_string_literal: true

require "nokogiri"

module Bluesky
  module Cards
    DESCRIPTION = "meta[property='og:description'], meta[name='description']"
    EMBED = "app.bsky.embed.external"
    HTML = "html"
    IMAGES = %w[image/gif image/jpeg image/png image/webp].freeze
    THUMB = "meta[property='og:image']"
    TITLE = "meta[property='og:title']"

    def self.embed(url, pages, &)
      page = pages.fetch(url)
      return unless ok?(page) && media_type(page).include?(HTML)

      document = Nokogiri::HTML5.parse(page.body)
      description = text(document.at_css(DESCRIPTION)&.[]("content"))
      thumb = thumb(document, page.url, pages, &)

      { "$type" => EMBED, external: { description:, thumb:, title: title(document), uri: url }.compact }
    rescue PageFetcher::Client::Error
      nil
    end

    def self.media_type(response) = response.headers["content-type"].to_s.split(";").first.to_s.strip.downcase
    private_class_method :media_type

    def self.ok?(response) = PageFetcher::Client::OK_STATUSES.cover?(response.status)
    private_class_method :ok?

    def self.picture?(image, pages)
      ok?(image) && IMAGES.include?(media_type(image)) && image.bytes.bytesize < pages.max_body
    end
    private_class_method :picture?

    def self.text(value) = Blog::Helpers::Whitespace.squish(value.to_s)
    private_class_method :text

    def self.thumb(document, base, pages)
      source = text(document.at_css(THUMB)&.[]("content"))
      return if source.empty?

      image = pages.fetch(URI.join(base, source).to_s)
      return unless picture?(image, pages)

      Images.blob(yield(*Images.fit(image.bytes, media_type(image))))
    rescue PageFetcher::Client::Error, URI::Error, Vips::Error
      nil
    end
    private_class_method :thumb

    def self.title(document)
      [document.at_css(TITLE)&.[]("content"), document.at_css("title")&.text].map { text(it) }.find { !it.empty? }.to_s
    end
    private_class_method :title
  end
end
