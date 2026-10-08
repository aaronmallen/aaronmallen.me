# frozen_string_literal: true

module Tasks
  module Structs
    class TaskSource < Blog::DB::Struct
      CHECK_CLOSED_EVERY = 24 * 60 * 60
      CLOSED = %w[completed not_planned unassigned].map { Blog::Types::TaskSourceState[it] }.freeze
      GONE = %w[moved deleted].map { Blog::Types::TaskSourceState[it] }.freeze
      LINEAR = Blog::Types::TaskSourceProvider["linear"]

      def due?(now)
        return false if GONE.include?(remote_state)

        !CLOSED.include?(remote_state) || checked_at.nil? || checked_at <= now - CHECK_CLOSED_EVERY
      end

      def next_cursor(updated_at, history, now)
        return unless provider == LINEAR
        return history_cursor || now unless history

        [history_cursor, updated_at, *history.map { it[:at] }].compact.max
      end
    end
  end
end
