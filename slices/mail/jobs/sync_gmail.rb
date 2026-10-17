# frozen_string_literal: true

module Mail
  module Jobs
    class SyncGmail < Blog::ScheduledJob
      BACKFILL_STALLED_AFTER = 60 * 60
      SYNC = Blog::Types::SyncName["mail"]

      include Record::SyncBookkeeping
      include Deps["operations.sync_gmail", "repos.gmail_backfills"]

      def perform = record_sync(SYNC) { sync_gmail.call }.then { resume_stalled_backfills }

      private

      def resume_stalled_backfills
        gmail_backfills.resume(Time.now - BACKFILL_STALLED_AFTER).each { BackfillGmail.perform_async(*it) }
      end
    end
  end
end
