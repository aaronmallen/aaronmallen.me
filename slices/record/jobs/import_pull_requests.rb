# frozen_string_literal: true

module Record
  module Jobs
    class ImportPullRequests < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["pull_requests"]

      include Deps[
        import_pull_requests: "operations.import_pull_requests",
        pull_request_mutations: "repos.pull_request_mutations",
        record_sync_outcome: "operations.record_sync_outcome",
      ]

      def perform
        result = record_crash(SYNC) { pull_request_mutations.with_import_lock { import_pull_requests.call } }

        record_outcome(SYNC, result)
      end
    end
  end
end
