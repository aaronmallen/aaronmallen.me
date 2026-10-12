# frozen_string_literal: true

module Mail
  module Jobs
    class SyncGmail < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["mail"]

      include Deps[record_sync_outcome: "record.operations.record_sync_outcome", sync_gmail: "operations.sync_gmail"]

      def perform = record_sync_outcome.call(SYNC, sync_gmail.call)
    end
  end
end
