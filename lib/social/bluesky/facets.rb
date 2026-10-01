# frozen_string_literal: true

module Social
  module Bluesky
    module Facets
      LINK = "app.bsky.richtext.facet#link"
      MENTION = "app.bsky.richtext.facet#mention"
      TAG = "app.bsky.richtext.facet#tag"

      def self.facet(feature, span)
        { features: [feature], index: { byteEnd: span.byte_end, byteStart: span.byte_start } }
      end
      private_class_method :facet

      def self.for(text, mentions: [])
        spans(text, mentions).map do |span|
          case span
          in Mentions::Mention then facet({ "$type" => MENTION, did: span.did }, span)
          in Links::Link then facet({ "$type" => LINK, uri: span.url }, span)
          in Tags::Tag then facet({ "$type" => TAG, tag: span.tag }, span)
          end
        end
      end

      def self.overlap?(one, other) = one.byte_start < other.byte_end && other.byte_start < one.byte_end
      private_class_method :overlap?

      def self.spans(text, mentions)
        found = [mentions, Links.new(text).to_a, Tags.new(text).to_a].reduce([]) do |kept, spans|
          kept + spans.reject { |span| kept.any? { overlap?(it, span) } }
        end

        found.sort_by(&:byte_start)
      end
      private_class_method :spans
    end
  end
end
