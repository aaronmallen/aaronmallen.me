# frozen_string_literal: true

module Social
  module Operations
    class CountNetworkLengths
      include Deps[measure_parts: "operations.measure_parts", resolve_mentions: "operations.resolve_mentions"]

      def call(bodies)
        names = Blog::Types::NetworkName.values
        shown = names.to_h { [it, resolve_mentions.call(bodies, it).map(&:text)] }

        measure_parts.call(bodies, names).each_with_index.map do |lengths, index|
          lengths.to_h { |name, length| [name, count(length, shown.fetch(name)[index])] }
        end
      end

      private

      def count(length, text) = Structs::NetworkCount.new(count: length.count, over: length.over, text:)
    end
  end
end
