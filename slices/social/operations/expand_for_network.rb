# frozen_string_literal: true

module Social
  module Operations
    class ExpandForNetwork
      include Deps[mention_directory: "queries.mention_directory", tag_links: "operations.tag_links"]

      def call(bodies, network)
        tagged = Array(bodies).map { tag_links.call(it, network) }
        directory = mention_directory.call(tagged)

        tagged.map { directory.expand(it, network) }
      end
    end
  end
end
