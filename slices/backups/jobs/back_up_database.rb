# frozen_string_literal: true

module Backups
  module Jobs
    class BackUpDatabase < Blog::ScheduledJob
      class BackupFailed < StandardError; end

      NOT_CONFIGURED = "Backups are not configured, so no dump ran"
      SYNC = Blog::Types::SyncName["backups"]

      include Record::SyncBookkeeping
      include Deps["operations.back_up_database"]

      def perform
        case back_up_database.call
          in Failure(:not_configured) then logger.warn(NOT_CONFIGURED)
          in Success(*) => result then record_sync_outcome.call(SYNC, result)
          in Failure(*reason) => result
            record_and_raise(SYNC, result, BackupFailed.new(reason.join(": ")))
        end
      end
    end
  end
end
