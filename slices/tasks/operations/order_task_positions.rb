# frozen_string_literal: true

module Tasks
  module Operations
    class OrderTaskPositions
      def call(held, id, after_id)
        order = arrange(held, id, after_id)
        return unless order

        order.zip(rising(held.map(&:position))).filter_map do |task, position|
          [task.id, position] unless task.position == position
        end
      end

      private

      def arrange(held, id, after_id)
        moved, rest = held.partition { it.id == id }
        at = after_id ? rest.index { it.id == after_id }&.succ : 0

        rest.insert(at, *moved) unless moved.empty? || at.nil?
      end

      def rising(positions)
        positions.each_with_object([]) { |position, out| out << [position, out.last.to_i + 1].max }
      end
    end
  end
end
