# frozen_string_literal: true

module Social
  module Bluesky
    module Facets
      LINK = "app.bsky.richtext.facet#link"
      TAG = "app.bsky.richtext.facet#tag"

      def self.facet(feature, span)
        { features: [feature], index: { byteEnd: span.byte_end, byteStart: span.byte_start } }
      end
      private_class_method :facet

      def self.for(text)
        links = Links.new(text).to_a
        tags = Tags.new(text).to_a.reject { |tag| links.any? { overlap?(it, tag) } }

        (links + tags).sort_by(&:byte_start).map do |span|
          case span
          in Links::Link then facet({ "$type" => LINK, uri: span.url }, span)
          in Tags::Tag then facet({ "$type" => TAG, tag: span.tag }, span)
          end
        end
      end

      def self.overlap?(one, other) = one.byte_start < other.byte_end && other.byte_start < one.byte_end
      private_class_method :overlap?
    end
  end
end
