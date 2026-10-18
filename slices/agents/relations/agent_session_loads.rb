# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessionLoads < Blog::DB::Relation
      schema :agent_session_loads, infer: true

      def with_paths
        join(:memory_files, id: self[:memory_file_id].qualified)
          .select_append(memory_files[:path].qualified)
          .order(memory_files[:path].qualified.asc)
      end
    end
  end
end
