# frozen_string_literal: true

module Admin
  module Operations
    class CountNetworkLengths
      include Deps[networks: "social.networks.all"]

      def call(bodies)
        bodies.map { |body| Blog::Types::NetworkName.values.to_h { [it, measure(networks.fetch(it), body)] } }
      end

      private

      def measure(client, body)
        Structs::NetworkCount.new(count: client.count(body), over: !client.within_limit?(body))
      end
    end
  end
end
