# frozen_string_literal: true

module Notes
  module Operations
    class UntagNote < Blog::TagOperation
      include Deps[
        mutations: "repos.note_mutations",
        queries: "repos.note_queries",
      ]

      private

      def change(id, name) = mutations.remove_tag(id, name)
    end
  end
end
