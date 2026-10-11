# frozen_string_literal: true

module Admin
  module Helpers
    module ShareLink
      MARKDOWN_SPECIAL = /[\\\[\]]/
      PREVIEW = "?preview"
      SCHEME = %r{\Ahttps?://}

      module_function

      def bare(link) = link.sub(SCHEME, "").chomp("/")

      def for(code) = "#{origin}/#{code}"

      def host = bare(origin)

      def markdown(text, link) = "[#{text.to_s.gsub(MARKDOWN_SPECIAL) { "\\#{it}" }}](#{link})"

      def origin = Hanami.app.settings.share_site[:url].chomp("/")

      def preview(code) = "#{self.for(code)}#{PREVIEW}"
    end
  end
end
