# frozen_string_literal: true

module Social
  module Operations
    class CheckNetworkFit
      include Deps[measure_parts: "operations.measure_parts"]

      def call(bodies, targets)
        measure_parts.call(bodies, targets.to_a).none? { it.each_value.any?(&:over) }
      end
    end
  end
end
