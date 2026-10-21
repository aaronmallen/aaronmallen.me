# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessionSearchHits < Blog::DB::Relation
      schema :agent_session_search_hits, infer: true

      def with_removal
        left_join(:memory_facts, id: self[:memory_fact_id].qualified)
          .select_append(memory_facts[:removed_at].qualified)
          .order(self[:id].qualified.asc)
      end
    end
  end
end
