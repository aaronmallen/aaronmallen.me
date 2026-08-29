# frozen_string_literal: true

module Record
  module Queries
    class CommitsLastSyncedAt
      include Deps[commit_repo: "repos.commit_repo"]

      def call = commit_repo.last_synced_at
    end
  end
end
