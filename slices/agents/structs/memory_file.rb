# frozen_string_literal: true

module Agents
  module Structs
    class MemoryFile < Blog::DB::Struct
      def description_by_agent? = !description_agent.nil?

      def facts = memory_facts

      def target = repo || project_id || task_id
    end
  end
end
