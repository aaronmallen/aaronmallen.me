# frozen_string_literal: true

module Admin
  module Operations
    class CountNetworkLengths
      include Deps[mention_directory: "social.queries.mention_directory", networks: "social.networks.all"]

      def call(bodies)
        directory = mention_directory.call(bodies)

        bodies.map do |body|
          Blog::Types::NetworkName.values.to_h { [it, measure(networks.fetch(it), directory.expand(body, it).text)] }
        end
      end

      private

      def measure(client, text)
        Structs::NetworkCount.new(count: client.count(text), over: !client.within_limit?(text), text:)
      end
    end
  end
end
