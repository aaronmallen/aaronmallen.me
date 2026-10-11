# frozen_string_literal: true

module Social
  module Operations
    class ExpandForNetwork
      include Deps[
        resolve_mentions: "operations.resolve_mentions",
        shorten_links: "operations.shorten_links",
        tag_links: "operations.tag_links",
      ]

      def call(bodies, network, make_links: false)
        texts = Array(bodies).map { shorten_links.call(tag_links.call(it, network), make: make_links) }

        resolve_mentions.call(texts, network)
      end
    end
  end
end
