# frozen_string_literal: true

module Record
  module Operations
    class RecordSyncOutcome
      include Deps[sync_state_mutations: "repos.sync_state_mutations"]

      def call(sync, result, repo: nil)
        result.either(
          ->(_) { sync_state_mutations.clear_failure(sync, repo:) },
          ->(failure) { record(sync, failure, repo:) },
        )
      end

      private

      def record(sync, failure, repo:)
        reason, message = Array(failure)

        sync_state_mutations.record_failure(sync, reason, message:, repo:)
      end
    end
  end
end
