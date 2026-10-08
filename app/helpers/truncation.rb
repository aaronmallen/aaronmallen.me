# frozen_string_literal: true

module Blog
  module Helpers
    module Truncation
      MARK = "…"

      def self.cut(text, keep:)
        value = text.to_s
        clusters = value.grapheme_clusters
        return value if clusters.length <= keep

        "#{clusters.first(keep).join.rstrip}#{MARK}"
      end

      def self.fit(text, limit:)
        value = text.to_s

        value.grapheme_clusters.length <= limit ? value : cut(value, keep: limit - MARK.length)
      end
    end
  end
end
