# frozen_string_literal: true

module Agents
  module Operations
    class TagSession < Blog::TagOperation
      include Deps[
        mutations: "repos.agent_session_mutations",
        queries: "repos.agent_session_queries",
      ]

      private

      def change(id, name) = mutations.add_tag(id, name)
    end
  end
end
