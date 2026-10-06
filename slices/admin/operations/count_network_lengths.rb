# frozen_string_literal: true

module Admin
  module Operations
    class CountNetworkLengths
      include Deps[
        mention_directory: "social.queries.mention_directory",
        networks: "social.networks.all",
        tag_links: "social.operations.tag_links",
      ]

      def call(bodies)
        directory = mention_directory.call(bodies)

        bodies.map do |body|
          Blog::Types::NetworkName.values.to_h { [it, measure(directory, body, it)] }
        end
      end

      private

      def measure(directory, body, name)
        client = networks.fetch(name)
        sent = directory.expand(tag_links.call(body, name), name).text

        Structs::NetworkCount.new(
          count: client.count(sent), over: !client.within_limit?(sent), text: directory.expand(body, name).text,
        )
      end
    end
  end
end
