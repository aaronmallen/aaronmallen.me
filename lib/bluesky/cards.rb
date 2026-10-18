# frozen_string_literal: true

require "nokogiri"
require "vips"

module Bluesky
  module Cards
    DESCRIPTION = "meta[name='description']"
    EMBED = "app.bsky.embed.external"
    HTML = "html"
    IMAGES = %w[image/gif image/jpeg image/png image/webp].freeze
    LOADERS = {
      "gifload_buffer" => "image/gif", "jpegload_buffer" => "image/jpeg", "pngload_buffer" => "image/png",
      "webpload_buffer" => "image/webp",
    }.freeze
    OG_DESCRIPTION = "meta[property='og:description']"
    THUMB = "meta[property='og:image']"
    TITLE = "meta[property='og:title']"

    def self.content(document, selector) = document.at_css(selector)&.[]("content")
    private_class_method :content

    def self.embed(url, pages, &)
      page = pages.fetch(url)
      return unless ok?(page) && media_type(page).include?(HTML)

      document = Nokogiri::HTML5.parse(page.body)
      description = first(content(document, OG_DESCRIPTION), content(document, DESCRIPTION))
      thumb = thumb(document, page.url, pages, &)

      { "$type" => EMBED, external: { description:, thumb:, title: title(document), uri: url }.compact }
    rescue PageFetcher::Client::Error
      nil
    end

    def self.first(*values) = values.map { text(it) }.find { !it.empty? }.to_s
    private_class_method :first

    def self.media_type(response) = response.headers["content-type"].to_s.split(";").first.to_s.strip.downcase
    private_class_method :media_type

    def self.ok?(response) = PageFetcher::Client::OK_STATUSES.cover?(response.status)
    private_class_method :ok?

    def self.picture?(image, pages)
      ok?(image) && IMAGES.include?(media_type(image)) && image.bytes.bytesize < pages.max_body
    end
    private_class_method :picture?

    def self.sniff(bytes)
      header = Vips::Image.new_from_buffer(bytes, "")
      return if header.width * header.height > ::Media::Operations::ProcessPhoto::MAX_PIXELS

      LOADERS[header.get("vips-loader")]
    end
    private_class_method :sniff

    def self.text(value) = Blog::Helpers::Whitespace.squish(value.to_s)
    private_class_method :text

    def self.thumb(document, base, pages)
      source = text(content(document, THUMB))
      return if source.empty?

      image = pages.fetch(URI.join(base, source).to_s)
      type = picture?(image, pages) && sniff(image.bytes)
      return unless type

      Images.blob(yield(*Images.fit(image.bytes, type)))
    rescue Expired, RateLimited
      raise
    rescue Error, PageFetcher::Client::Error, URI::Error, Vips::Error
      nil
    end
    private_class_method :thumb

    def self.title(document) = first(content(document, TITLE), document.at_css("title")&.text)
    private_class_method :title
  end
end
