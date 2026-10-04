# frozen_string_literal: true

module Backups
  module Jobs
    class BackUpDatabase < Blog::Job
      class BackupFailed < StandardError; end

      NOT_CONFIGURED = "Backups are not configured, so no dump ran"

      include Deps[
        back_up_database: "operations.back_up_database",
        record_backup_sync_outcome: "record.operations.record_backup_sync_outcome",
      ]

      sidekiq_options retry: false

      def perform
        case back_up_database.call
        in Failure(:not_configured) then logger.warn(NOT_CONFIGURED)
        in Success(*) => result then record_backup_sync_outcome.call(result)
        in Failure(*reason) => result then report(result, reason)
        end
      end

      private

      def report(result, reason)
        record_backup_sync_outcome.call(result)
        raise BackupFailed, reason.join(": ")
      end
    end
  end
end
