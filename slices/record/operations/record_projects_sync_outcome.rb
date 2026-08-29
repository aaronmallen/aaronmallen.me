# frozen_string_literal: true

module Record
  module Operations
    class RecordProjectsSyncOutcome
      include Deps[record_sync_outcome: "operations.record_sync_outcome"]

      def call(result) = record_sync_outcome.call(Repos::SyncStateRepo::PROJECTS, result)
    end
  end
end
