# frozen_string_literal: true

module Calendar
  module Jobs
    class SyncCalendar < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["calendar"]

      include Record::SyncBookkeeping
      include Deps["operations.sync_calendar"]

      def perform = record_sync(SYNC) { sync_calendar.call }
    end
  end
end
