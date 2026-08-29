# frozen_string_literal: true

module Record
  module Queries
    class SyncFailures
      include Deps[sync_state_repo: "repos.sync_state_repo"]

      def call = sync_state_repo.failures
    end
  end
end
