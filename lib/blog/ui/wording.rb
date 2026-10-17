# frozen_string_literal: true

module Blog
  module UI
    module Wording
      DOT = " · "
      SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i
      WRITTEN = /\S/

      def dotted(*parts) = parts.select { written?(it) }.join(DOT)

      def written?(value) = value.to_s.match?(WRITTEN)

      module_function

      def bare_url(url) = url.to_s.sub(SCHEME, "").chomp("/")
    end
  end
end
