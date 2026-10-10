# frozen_string_literal: true

module Projects
  module Jobs
    class RefreshProjects < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["projects"]

      include Deps[
        record_sync_outcome: "record.operations.record_sync_outcome",
        refresh_projects: "operations.refresh_projects",
      ]

      def perform = record_sync_outcome.call(SYNC, refresh_projects.call)
    end
  end
end
