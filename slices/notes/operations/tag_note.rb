# frozen_string_literal: true

module Notes
  module Operations
    class TagNote < Blog::TagOperation
      include Deps[
        mutations: "repos.note_mutations",
        queries: "repos.note_queries",
      ]

      private

      def change(id, name) = mutations.add_tag(id, name)
    end
  end
end
