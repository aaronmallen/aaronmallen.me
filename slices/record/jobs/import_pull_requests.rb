# frozen_string_literal: true

module Record
  module Jobs
    class ImportPullRequests < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["pull_requests"]

      include SyncBookkeeping
      include Deps["operations.import_pull_requests", "repos.pull_request_mutations"]

      def perform = record_sync(SYNC) { pull_request_mutations.with_import_lock { import_pull_requests.call } }
    end
  end
end
