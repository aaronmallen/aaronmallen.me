# frozen_string_literal: true

module Social
  module Operations
    class CheckNetworkFit
      include Deps[expand_for_network: "operations.expand_for_network", networks: "networks.all"]

      def call(bodies, targets)
        targets.to_a.all? do |name|
          client = networks.fetch(name)
          expand_for_network.call(bodies, name).all? { client.within_limit?(it.text) }
        end
      end
    end
  end
end
