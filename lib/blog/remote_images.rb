# frozen_string_literal: true

require "nokogiri"
require "uri"

module Blog
  module RemoteImages
    ALT = "alt"
    ANCHOR = "a"
    HREF = "href"
    IMG = "img"
    MEDIA = %r{\A/media/[\w.-]+\z}
    SRC = "src"

    module_function

    def find(fragment) = fragment.css(IMG).reject { own?(it[SRC]) }

    def linkable?(src)
      uri = URI(src)
      uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
    rescue URI::InvalidURIError
      false
    end

    def own?(src)
      uri = URI(src.to_s)
      return false unless MEDIA.match?(uri.path) && uri.query.nil? && uri.fragment.nil?

      uri.is_a?(URI::HTTP) ? uri.origin == Site.origin : uri.host.nil? && uri.scheme.nil?
    rescue URI::InvalidURIError
      false
    end

    def stand_in(image)
      src = image[SRC].to_s
      alt = image[ALT].to_s.strip
      return image.document.create_text_node(alt) unless linkable?(src)

      text = alt.empty? ? src : alt
      return image.document.create_text_node(text) if image.ancestors(ANCHOR).any?

      image.document.create_element(ANCHOR, text, HREF => src)
    end

    def swap(images) = images.each { it.replace(stand_in(it)) }

    def to_links(html)
      fragment = Nokogiri::HTML5.fragment(html)
      images = find(fragment)
      return html if images.empty?

      swap(images)
      fragment.to_html
    end
  end
end
