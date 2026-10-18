# frozen_string_literal: true

module Mail
  module Jobs
    class SyncGmail < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["mail"]

      include Record::SyncBookkeeping
      include Deps["operations.sync_gmail"]

      def perform = record_locked_sync(SYNC) { sync_gmail.call }
    end
  end
end
