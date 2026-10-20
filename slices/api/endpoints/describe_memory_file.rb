# frozen_string_literal: true

module API
  module Endpoints
    class DescribeMemoryFile < MemoryEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, description: Memory::DESCRIPTION, **Memory::AUTHOR },
        required: %w[id description agent model],
      }.freeze

      REPLY = Serializers::MemoryFile.reference

      include Deps[describe_memory_file: "agents.operations.describe_memory_file"]

      def handle(id:, **fields)
        settled(describe_memory_file.call(id, fields), id) { serialized(Serializers::MemoryFile, it) }
      end
    end
  end
end
