# frozen_string_literal: true

module Record
  module Operations
    class RecordCountrySyncOutcome
      include Deps[record_sync_outcome: "operations.record_sync_outcome"]

      def call(result) = record_sync_outcome.call(Blog::Types::SyncName["country_database"], result)
    end
  end
end
