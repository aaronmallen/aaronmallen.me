# frozen_string_literal: true

module Calendar
  module Jobs
    class SyncCalendar < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["calendar"]

      include Deps["operations.sync_calendar", record_sync_outcome: "record.operations.record_sync_outcome"]

      def perform = record_crash(SYNC) { record_sync_outcome.call(SYNC, sync_calendar.call) }
    end
  end
end
