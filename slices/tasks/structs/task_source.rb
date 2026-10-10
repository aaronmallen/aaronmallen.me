# frozen_string_literal: true

module Tasks
  module Structs
    class TaskSource < Blog::DB::Struct
      CHECK_CLOSED_EVERY = 24 * 60 * 60
      CLOSED = Blog::Types::ClosedTaskSourceState
      GONE = Blog::Types::GoneTaskSourceState
      LINEAR = Blog::Types::TaskSourceProvider["linear"]

      def due?(now)
        return false if GONE.valid?(remote_state)

        !CLOSED.valid?(remote_state) || checked_at.nil? || checked_at <= now - CHECK_CLOSED_EVERY
      end

      def next_cursor(updated_at, history, now)
        return unless provider == LINEAR
        return history_cursor || now unless history

        [history_cursor, updated_at, *history.map { it[:at] }].compact.max
      end
    end
  end
end
