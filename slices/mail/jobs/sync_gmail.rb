# frozen_string_literal: true

module Mail
  module Jobs
    class SyncGmail < Blog::ScheduledJob
      BACKFILL_STALLED_AFTER = 60 * 60
      SYNC = Blog::Types::SyncName["mail"]

      include Deps[
        gmail_backfills: "repos.gmail_backfills",
        record_sync_outcome: "record.operations.record_sync_outcome",
        sync_gmail: "operations.sync_gmail",
      ]

      def perform
        record_crash(SYNC) { record_sync_outcome.call(SYNC, sync_gmail.call) }
        gmail_backfills.resume(Time.now - BACKFILL_STALLED_AFTER).each { BackfillGmail.perform_async(*it) }
      end
    end
  end
end
