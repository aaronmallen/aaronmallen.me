# frozen_string_literal: true

module Social
  module Operations
    class ExpandForNetwork
      include Deps[
        networks: "social_networks.all",
        resolve_mentions: "operations.resolve_mentions",
        shorten_links: "operations.shorten_links",
        tag_links: "operations.tag_links",
      ]

      def call(bodies, network, make_links: false)
        texts = joined(Array(bodies), network).map { shorten_links.call(tag_links.call(it, network), make: make_links) }

        resolve_mentions.call(texts, network)
      end

      private

      def joined(bodies, network)
        joiner = networks.fetch(network).joiner

        joiner ? [bodies.join(joiner)] : bodies
      end
    end
  end
end
