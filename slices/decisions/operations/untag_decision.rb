# frozen_string_literal: true

module Decisions
  module Operations
    class UntagDecision < Blog::TagOperation
      include Deps[
        mutations: "repos.decision_mutations",
        queries: "repos.decision_queries",
      ]

      private

      def change(id, name) = mutations.remove_tag(id, name)
    end
  end
end
