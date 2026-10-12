# frozen_string_literal: true

module Projects
  module Operations
    class UntagProject < Blog::Operation
      include Deps[project_mutations: "repos.project_mutations", project_queries: "repos.project_queries"]

      def call(id, name)
        transaction do
          step find(id)
          project_mutations.remove_tag(id, name)
          project_queries.by_id(id)
        end
      end

      private

      def find(id) = found(project_queries.by_id(id) && id)
    end
  end
end
