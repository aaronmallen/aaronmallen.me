# frozen_string_literal: true

module Tasks
  module Queries
    class SyncedTaskIds
      include Deps[task_source_repo: "repos.task_source_repo"]

      def call(ids) = task_source_repo.synced_task_ids(ids)
    end
  end
end
