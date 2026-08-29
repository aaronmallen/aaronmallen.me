# frozen_string_literal: true

module Record
  module Operations
    class RecordCountrySyncOutcome
      include Deps[record_sync_outcome: "operations.record_sync_outcome"]

      def call(result) = record_sync_outcome.call(Repos::SyncStateRepo::COUNTRY_DATABASE, result)
    end
  end
end
