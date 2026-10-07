# frozen_string_literal: true

module Projects
  module Operations
    class RestoreProject < Operation
      include Deps[project_repo: "repos.project_repo"]

      def call(id)
        step find(id)
        project_repo.update(id, archived_on: nil)
      end

      private

      def find(id)
        found(project_repo.by_id(id)&.archived? && id)
      end
    end
  end
end
