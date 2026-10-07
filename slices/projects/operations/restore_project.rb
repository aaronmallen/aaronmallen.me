# frozen_string_literal: true

module Projects
  module Operations
    class RestoreProject < Operation
      include Deps[project_mutations: "repos.project_mutations", project_queries: "repos.project_queries"]

      def call(id)
        step find(id)
        project_mutations.update(id, archived_on: nil)
      end

      private

      def find(id)
        found(project_queries.by_id(id)&.archived? && id)
      end
    end
  end
end
