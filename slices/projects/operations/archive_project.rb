# frozen_string_literal: true

module Projects
  module Operations
    class ArchiveProject < Operation
      include Deps[project_repo: "repos.project_repo"]

      def call(id, on: Blog::TimeZone.today)
        project = step find(id)
        step started(project, on)
        project_repo.update(id, status: Blog::Types::ProjectStatus["archived"], archived_on: on, featured: false)
      end

      private

      def find(id)
        found(project_repo.by_id(id))
      end

      def started(project, on)
        starts = project.started_on

        starts && starts > on ? Failure(:not_started) : Success(project)
      end
    end
  end
end
