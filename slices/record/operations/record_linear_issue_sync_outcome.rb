# frozen_string_literal: true

module Record
  module Operations
    class RecordLinearIssueSyncOutcome
      include Deps[record_sync_outcome: "operations.record_sync_outcome"]

      def call(result) = record_sync_outcome.call(Repos::SyncStateRepo::LINEAR_ISSUES, result)
    end
  end
end
