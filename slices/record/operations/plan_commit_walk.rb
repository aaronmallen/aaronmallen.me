# frozen_string_literal: true

module Record
  module Operations
    class PlanCommitWalk
      EMPTY_STEP = 60 * 60
      OVERLAP = 24 * 60 * 60

      def call(branches, edge, floor: nil)
        return [:walked] if branches.all? { it[:complete] } || floored?(branches, edge, floor)
        return [:grounded, branches.reject { it[:complete] }.map { it[:name] }] if grounded?(branches, edge)

        [:next, next_edge(branches, edge)]
      end

      private

      def covered(branches)
        branches.reject { it[:complete] }.filter_map { it[:commits].last&.fetch(:committed_at) }.max
      end

      def floored?(branches, edge, floor) = !floor.nil? && next_edge(branches, edge) <= floor

      def grounded?(branches, edge)
        made = branches.filter_map { it[:created_at] }.max
        return false if made.nil? || covered(branches)

        next_edge(branches, edge) <= made
      end

      def next_edge(branches, edge)
        reached = covered(branches)

        reached ? [reached, edge - 1].min : edge - EMPTY_STEP
      end
    end
  end
end
