# frozen_string_literal: true

module Projects
  module Operations
    class ArchiveProject < Blog::Operation
      include Deps[project_mutations: "repos.project_mutations", project_queries: "repos.project_queries"]

      def call(id, on: Blog::TimeZone.today)
        project = step find(id)
        step started(project, on)
        project_mutations.update(id, archived_on: on)
      end

      private

      def find(id)
        found(project_queries.by_id(id))
      end

      def started(project, on)
        starts = project.started_on

        starts && starts > on ? Failure(:not_started) : Success(project)
      end
    end
  end
end
