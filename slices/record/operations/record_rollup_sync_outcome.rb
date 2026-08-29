# frozen_string_literal: true

module Record
  module Operations
    class RecordRollupSyncOutcome
      include Deps[record_sync_outcome: "operations.record_sync_outcome"]

      def call(result) = record_sync_outcome.call(Repos::SyncStateRepo::ANALYTICS_ROLLUP, result)
    end
  end
end
