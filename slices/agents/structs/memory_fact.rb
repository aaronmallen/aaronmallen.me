# frozen_string_literal: true

module Agents
  module Structs
    class MemoryFact < Blog::DB::Struct
      def agent? = !agent.nil?

      def removed? = !removed_at.nil?

      def was = { was_type: type, was_text: text, was_agent: agent, was_model: model }
    end
  end
end
