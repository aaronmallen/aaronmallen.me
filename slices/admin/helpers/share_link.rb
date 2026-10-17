# frozen_string_literal: true

require "uri"

module Admin
  module Helpers
    class ShareLink
      MARKDOWN_SPECIAL = /[\\\[\]]/
      PREVIEW = "?preview"

      include Deps["settings"]

      class << self
        def bare_for(code) = Blog::UI::Wording.bare_url(self.for(code))

        def domain(destination) = URI.parse(destination).host.to_s.delete_prefix("www.")

        def file_markdown(share, link)
          return markdown(share.filename, link) unless Shares::ContentType.image?(share.content_type)

          image_markdown(share.alt_text, link)
        end

        def for(...) = new.for(...)

        def host = new.host

        def image_markdown(alt, link) = "!#{markdown(alt, link)}"

        def link_name(link) = link.title || domain(link.destination)

        def markdown(text, link) = "[#{text.to_s.gsub(MARKDOWN_SPECIAL) { "\\#{it}" }}](#{link})"

        def preview(code) = new.preview(code)
      end

      def for(code, file_id = nil) = settings.share_url(code, file_id)

      def host = Blog::UI::Wording.bare_url(settings.share_site[:url])

      def preview(code) = "#{self.for(code)}#{PREVIEW}"
    end
  end
end
