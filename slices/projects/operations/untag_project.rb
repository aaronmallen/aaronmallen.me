# frozen_string_literal: true

module Projects
  module Operations
    class UntagProject < Blog::TagOperation
      include Deps[
        mutations: "repos.project_mutations",
        queries: "repos.project_queries",
      ]

      private

      def change(id, name) = mutations.remove_tag(id, name)
    end
  end
end
