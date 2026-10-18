# frozen_string_literal: true

require "vips"

module Bluesky
  module Cards
    DESCRIPTION = "meta[name='description']"
    EMBED = "app.bsky.embed.external"
    IMAGES = %w[image/gif image/jpeg image/png image/webp].freeze
    LOADERS = {
      "gifload_buffer" => "image/gif", "jpegload_buffer" => "image/jpeg", "pngload_buffer" => "image/png",
      "webpload_buffer" => "image/webp",
    }.freeze
    OG_DESCRIPTION = "meta[property='og:description']"
    THUMB = "meta[property='og:image']"

    def self.content(document, selector) = document.at_css(selector)&.[]("content")
    private_class_method :content

    def self.embed(url, pages, &)
      page = pages.fetch(url)
      document = PageFetcher::Page.document(page)
      return unless document

      description = first(content(document, OG_DESCRIPTION), content(document, DESCRIPTION))
      thumb = thumb(document, page.url, pages, &)
      title = PageFetcher::Page.title(document).to_s

      { "$type" => EMBED, external: { description:, thumb:, title:, uri: url }.compact }
    rescue PageFetcher::Client::Error
      nil
    end

    def self.first(*values) = values.map { PageFetcher::Page.text(it) }.find { !it.empty? }.to_s
    private_class_method :first

    def self.picture?(image, pages)
      image.success? && IMAGES.include?(image.media_type) && image.bytes.bytesize < pages.max_body
    end
    private_class_method :picture?

    def self.sniff(bytes)
      header = Vips::Image.new_from_buffer(bytes, "")
      return if header.width * header.height > ::Media::Operations::ProcessPhoto::MAX_PIXELS

      LOADERS[header.get("vips-loader")]
    end
    private_class_method :sniff

    def self.thumb(document, base, pages)
      source = PageFetcher::Page.text(content(document, THUMB))
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
  end
end
