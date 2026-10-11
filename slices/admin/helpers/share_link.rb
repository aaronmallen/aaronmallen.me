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

        def for(code) = new.for(code)

        def host = new.host

        def markdown(text, link) = "[#{text.to_s.gsub(MARKDOWN_SPECIAL) { "\\#{it}" }}](#{link})"

        def origin = new.origin

        def preview(code) = new.preview(code)
      end

      def for(code) = "#{origin}/#{code}"

      def host = self.class.bare(origin)

      def origin = settings.share_site[:url].chomp("/")

      def preview(code) = "#{self.for(code)}#{PREVIEW}"
    end
  end
end
