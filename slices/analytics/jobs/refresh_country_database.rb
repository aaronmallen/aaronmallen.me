# frozen_string_literal: true

module Analytics
  module Jobs
    class RefreshCountryDatabase < Blog::Job
      class RefreshFailed < StandardError; end

      QUIET = :not_configured

      include Deps[
        record_country_sync_outcome: "record.operations.record_country_sync_outcome",
        refresh_country_database: "operations.refresh_country_database",
      ]

      sidekiq_options retry: false

      def perform
        case refresh_country_database.call
        in Success(*) | Failure(QUIET) then record_country_sync_outcome.call(Success(nil))
        in Failure(*reason) then report(reason)
        end
      end

      private

      def report(reason)
        record_country_sync_outcome.call(Failure(reason))
        raise RefreshFailed, reason.join(": ")
      end
    end
  end
end
