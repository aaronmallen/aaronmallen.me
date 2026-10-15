# frozen_string_literal: true

module Record
  module Jobs
    class ImportPullRequests < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["pull_requests"]

      include Deps[
        import_pull_requests: "operations.import_pull_requests",
        pull_request_mutations: "repos.pull_request_mutations",
        record_sync_outcome: "operations.record_sync_outcome", # rubocop:disable Hanami/UnusedDeps
      ]

      def perform = record_outcome(SYNC, pull_request_mutations.with_import_lock { import_pull_requests.call })
    end
  end
end
