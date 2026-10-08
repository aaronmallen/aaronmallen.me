# frozen_string_literal: true

module Admin
  module Operations
    class CountNetworkLengths
      include Deps[
        expand_for_network: "social.operations.expand_for_network",
        networks: "social.networks.all",
        resolve_mentions: "social.operations.resolve_mentions",
      ]

      def call(bodies)
        shown = per_network { resolve_mentions.call(bodies, it) }
        sent = per_network { expand_for_network.call(bodies, it) }

        bodies.each_index.map do |index|
          sent.to_h { |name, texts| [name, measure(name, texts[index], shown[name][index])] }
        end
      end

      private

      def measure(name, sent, shown)
        client = networks.fetch(name)

        Structs::NetworkCount.new(count: client.count(sent), over: !client.within_limit?(sent), text: shown)
      end

      def per_network = Blog::Types::NetworkName.values.to_h { [it, yield(it).map(&:text)] }
    end
  end
end
