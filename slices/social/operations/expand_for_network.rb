# frozen_string_literal: true

module Social
  module Operations
    class ExpandForNetwork
      include Deps[resolve_mentions: "operations.resolve_mentions", tag_links: "operations.tag_links"]

      def call(bodies, network)
        resolve_mentions.call(Array(bodies).map { tag_links.call(it, network) }, network)
      end
    end
  end
end
