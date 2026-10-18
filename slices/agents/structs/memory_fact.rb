# frozen_string_literal: true

module Agents
  module Structs
    class MemoryFact < Blog::DB::Struct
      def agent? = !agent.nil?

      def removed? = !removed_at.nil?
    end
  end
end
