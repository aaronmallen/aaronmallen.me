# frozen_string_literal: true

module Projects
  module Jobs
    class RefreshProjects < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["projects"]

      include Record::SyncBookkeeping
      include Deps["operations.refresh_projects"]

      def perform = record_sync(SYNC) { refresh_projects.call }
    end
  end
end
