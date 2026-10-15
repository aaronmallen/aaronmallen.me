# frozen_string_literal: true

module Admin
  module Live
    class Batch
      def initialize(seconds)
        @heard = {}
        @span = seconds * 1_000_000
      end

      def <<(table)
        @heard[table] = Clock.now
        @due ||= Clock.now + @span
      end

      def due? = !@due.nil? && Clock.now >= @due

      def take
        @heard.map { |table, at| "id: #{at}\nevent: change\ndata: #{table}\n\n" }.join.tap do
          @heard.clear
          @due = nil
        end
      end

      def wait = (@due ? (@due - Clock.now).clamp(0, @span) : @span) / 1_000_000.0
    end
  end
end
