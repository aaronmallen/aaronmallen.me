# frozen_string_literal: true

module Projects
  module Operations
    class TagProject < Blog::TagOperation
      include Deps[
        mutations: "repos.project_mutations",
        queries: "repos.project_queries", # rubocop:disable Hanami/UnusedDeps
      ]

      private

      def change(id, name) = mutations.add_tag(id, name)
    end
  end
end
