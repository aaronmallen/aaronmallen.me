# frozen_string_literal: true

module Projects
  module Queries
    class PublicArchived
      include Deps[project_repo: "repos.project_repo"]

      def call = project_repo.public_archived
    end
  end
end
