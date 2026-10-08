# frozen_string_literal: true

module Social
  module Operations
    class MeasureParts
      include Deps[expand_for_network: "operations.expand_for_network", networks: "networks.all"]

      def call(bodies, targets)
        sent = targets.to_h { [it, expand_for_network.call(bodies, it).map(&:text)] }

        bodies.each_index.map do |index|
          sent.to_h { |name, texts| [name, measure(name, index + 1, texts[index])] }
        end
      end

      private

      def measure(name, part, text)
        client = networks.fetch(name)

        over = !client.within_limit?(text)

        Structs::PartLength.new(network: name, part:, count: client.count(text), limit: client.limit, over:)
      end
    end
  end
end
