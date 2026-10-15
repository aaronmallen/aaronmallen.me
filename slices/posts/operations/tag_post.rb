# frozen_string_literal: true

module Posts
  module Operations
    class TagPost < Blog::TagOperation
      include Deps[
        mutations: "repos.post_mutations",
        queries: "repos.post_queries",
      ]

      private

      def change(id, name) = mutations.add_tag(id, name)
    end
  end
end
