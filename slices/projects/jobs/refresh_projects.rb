# frozen_string_literal: true

module Projects
  module Jobs
    class RefreshProjects < Blog::ScheduledJob
      include Deps[
        record_projects_sync_outcome: "record.operations.record_projects_sync_outcome",
        refresh_projects: "operations.refresh_projects",
      ]

      def perform = record_projects_sync_outcome.call(refresh_projects.call)
    end
  end
end
