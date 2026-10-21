# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessionSearches < Blog::DB::Relation
      schema :agent_session_searches, infer: true do
        associations do
          has_many :agent_session_search_hits, view: :with_removal
        end
      end

      def in_order = order(self[:id].asc)
    end
  end
end
