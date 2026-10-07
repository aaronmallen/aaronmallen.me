# frozen_string_literal: true

module Social
  module Operations
    class ExpandForNetwork
      include Deps[person_queries: "repos.person_queries", tag_links: "operations.tag_links"]

      def call(bodies, network)
        tagged = Array(bodies).map { tag_links.call(it, network) }
        directory = person_queries.mention_directory(tagged)

        tagged.map { directory.expand(it, network) }
      end
    end
  end
end
