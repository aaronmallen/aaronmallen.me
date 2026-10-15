# frozen_string_literal: true

module Decisions
  module Operations
    class TagDecision < Blog::TagOperation
      include Deps[
        mutations: "repos.decision_mutations",
        queries: "repos.decision_queries",
      ]

      private

      def change(id, name) = mutations.add_tag(id, name)
    end
  end
end
