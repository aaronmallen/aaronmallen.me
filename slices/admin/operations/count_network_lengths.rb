# frozen_string_literal: true

module Admin
  module Operations
    class CountNetworkLengths
      include Deps[
        expand_for_network: "social.operations.expand_for_network",
        mention_directory: "social.queries.mention_directory",
        networks: "social.networks.all",
      ]

      def call(bodies)
        directory = mention_directory.call(bodies)
        sent = Blog::Types::NetworkName.values.to_h { [it, expand_for_network.call(bodies, it).map(&:text)] }

        bodies.each_with_index.map do |body, index|
          sent.to_h { |name, texts| [name, measure(directory, body, name, texts[index])] }
        end
      end

      private

      def measure(directory, body, name, sent)
        client = networks.fetch(name)

        Structs::NetworkCount.new(
          count: client.count(sent), over: !client.within_limit?(sent), text: directory.expand(body, name).text,
        )
      end
    end
  end
end
