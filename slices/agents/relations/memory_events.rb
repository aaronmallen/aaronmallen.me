# frozen_string_literal: true

module Agents
  module Relations
    class MemoryEvents < Blog::DB::Relation
      schema :memory_events, infer: true do
        associations do
          belongs_to :memory_file
        end
      end
    end
  end
end
