# frozen_string_literal: true

module Blog
  module UI
    module Wording
      DOT = " · "
      WRITTEN = /\S/

      def dotted(*parts) = parts.select { written?(it) }.join(DOT)

      def written?(value) = value.to_s.match?(WRITTEN)
    end
  end
end
