# frozen_string_literal: true

module Agents
  module Relations
    class MemoryFacts < Blog::DB::Relation
      schema :memory_facts, infer: true do
        associations do
          belongs_to :memory_file
        end
      end

      def live_in_order = where(removed_at: nil).oldest_first
    end
  end
end
