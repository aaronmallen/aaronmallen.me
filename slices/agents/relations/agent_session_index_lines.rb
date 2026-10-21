# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessionIndexLines < Blog::DB::Relation
      schema :agent_session_index_lines, infer: true

      def in_order = order(self[:id].asc)
    end
  end
end
