# frozen_string_literal: true

module Admin
  module Helpers
    module ShareLink
      SCHEME = %r{\Ahttps?://}

      module_function

      def bare(link) = link.sub(SCHEME, "").chomp("/")

      def for(code) = "#{origin}/#{code}"

      def host = bare(origin)

      def origin = Hanami.app.settings.share_site[:url].chomp("/")
    end
  end
end
