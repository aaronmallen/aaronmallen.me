# frozen_string_literal: true

module API
  module Endpoints
    class UntagMemoryFile < AgentTagging
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, tag: UNTAG },
        required: %w[id tag],
      }.freeze

      REPLY = Serializers::MemoryFile.reference

      include Deps[
        memory_file_queries: "agents.repos.memory_file_queries",
        untag_memory_file: "agents.operations.untag_memory_file",
      ]

      def handle(id:, tag:)
        untagged(:"memory file", id, memory_file_queries.by_id(id), tag) { untag_memory_file.call(id, it) }
      end
    end
  end
end
