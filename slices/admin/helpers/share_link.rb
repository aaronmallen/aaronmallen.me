# frozen_string_literal: true

module Admin
  module Helpers
    class ShareLink
      MARKDOWN_SPECIAL = /[\\\[\]]/
      PREVIEW = "?preview"
      SCHEME = %r{\Ahttps?://}

      include Deps["settings"]

      class << self
        def bare(link) = link.sub(SCHEME, "").chomp("/")

        def for(...) = new.for(...)

        def host = new.host

        def markdown(text, link) = "[#{text.to_s.gsub(MARKDOWN_SPECIAL) { "\\#{it}" }}](#{link})"

        def preview(code) = new.preview(code)
      end

      def for(code, file_id = nil) = settings.share_url(code, file_id)

      def host = self.class.bare(settings.share_site[:url])

      def preview(code) = "#{self.for(code)}#{PREVIEW}"
    end
  end
end
