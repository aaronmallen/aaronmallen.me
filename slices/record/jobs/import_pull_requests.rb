# frozen_string_literal: true

module Record
  module Jobs
    class ImportPullRequests < Blog::Job
      include Deps[
        import_pull_requests: "operations.import_pull_requests",
        pull_request_mutations: "repos.pull_request_mutations",
        record_sync_outcome: "operations.record_sync_outcome",
      ]

      sidekiq_options retry: false

      def perform
        result = pull_request_mutations.with_import_lock { import_pull_requests.call }

        case result
          in Failure(:lock_busy) then nil
          else record_sync_outcome.call(Blog::Types::SyncName["pull_requests"], result)
        end
      end
    end
  end
end
