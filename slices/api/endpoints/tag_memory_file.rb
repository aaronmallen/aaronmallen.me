# frozen_string_literal: true

module API
  module Endpoints
    class TagMemoryFile < AgentTagging
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, tag: TAG },
        required: %w[id tag],
      }.freeze

      REPLY = Serializers::MemoryFile.reference

      include Deps[tag_memory_file: "agents.operations.tag_memory_file"]

      def handle(id:, tag:) = tagged(:"memory file", id, tag) { tag_memory_file.call(id, it) }
    end
  end
end
