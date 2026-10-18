# frozen_string_literal: true

module Agents
  module Relations
    class MemoryEvents < Blog::DB::Relation
      schema :memory_events, infer: true do
        associations do
          belongs_to :memory_file
        end
      end

      def session_listed = select(:id, :memory_file_id, :memory_fact_id, :op, :session_id).order(self[:id].asc)
    end
  end
end
