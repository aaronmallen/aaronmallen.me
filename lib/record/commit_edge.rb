# frozen_string_literal: true

module Record
  module CommitEdge
    EMPTY_STEP = 60 * 60
    OVERLAP = 24 * 60 * 60

    module_function

    def covered(branches, floor)
      edges = branches.reject { it[:complete] }.filter_map { it[:commits].last&.fetch(:committed_at) }

      edges.max || floor
    end

    def created(branches) = branches.filter_map { it[:created_at] }.max

    def floored?(branches, edge, floor) = !floor.nil? && next_edge(branches, edge) <= floor

    def grounded?(branches, edge)
      made = created(branches)
      return false if made.nil? || covered(branches, nil)

      next_edge(branches, edge) <= made
    end

    def next_edge(branches, edge)
      reached = covered(branches, nil)

      reached ? [reached, edge - 1].min : edge - EMPTY_STEP
    end

    def unread(branches) = branches.reject { it[:complete] }.map { it[:name] }

    def walked?(branches) = branches.all? { it[:complete] }
  end
end
