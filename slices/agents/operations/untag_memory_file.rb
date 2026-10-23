# frozen_string_literal: true

module Agents
  module Operations
    class UntagMemoryFile < Blog::TagOperation
      include Deps[
        mutations: "repos.memory_file_mutations",
        queries: "repos.memory_file_queries",
      ]

      private

      def change(id, name) = mutations.remove_tag(id, name)
    end
  end
end
