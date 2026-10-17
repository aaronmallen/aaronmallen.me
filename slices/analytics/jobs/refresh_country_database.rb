# frozen_string_literal: true

module Analytics
  module Jobs
    class RefreshCountryDatabase < Blog::ScheduledJob
      class RefreshFailed < StandardError; end

      QUIET = :not_configured
      SYNC = Blog::Types::SyncName["country_database"]

      include Record::SyncBookkeeping
      include Deps["operations.refresh_country_database"]

      def perform
        case refresh_country_database.call
          in Success(*) | Failure(QUIET) then record_sync_outcome.call(SYNC, Success(nil))
          in Failure(*reason)
            record_and_raise(SYNC, Failure(reason), RefreshFailed.new(reason.join(": ")))
        end
      end
    end
  end
end
