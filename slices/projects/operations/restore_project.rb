# frozen_string_literal: true

module Projects
  module Operations
    class RestoreProject < Blog::Operation
      include Deps[project_repo: "repos.project_repo"]

      def call(id)
        step find(id)
        project_repo.update(id, status: Blog::Types::ProjectLiveStatus["active"], archived_on: nil)
      end

      private

      def find(id)
        project = project_repo.by_id(id)
        project&.archived? ? Success(id) : Failure(:not_found)
      end
    end
  end
end
