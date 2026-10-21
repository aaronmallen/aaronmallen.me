# frozen_string_literal: true

module Agents
  module Relations
    class AgentSessionReads < Blog::DB::Relation
      schema :agent_session_reads, infer: true

      def with_files
        left_join(:memory_files, id: self[:memory_file_id].qualified)
          .select_append(memory_files[:path].qualified, memory_files[:scope].qualified)
          .order(self[:id].qualified.asc)
      end
    end
  end
end
