# frozen_string_literal: true

module API
  module Endpoints
    class ReadMemoryFile < MemoryEndpoint
      HISTORY = "every change, oldest first"
      SCHEMA = Helpers::Schema.by_id

      REPLY = Helpers::Schema.widen(
        Serializers::MemoryFile::SCHEMA,
        history: Helpers::Schema.list(Serializers::MemoryEvent.reference).merge(description: HISTORY),
      ).freeze

      include Deps[memory_file_queries: "agents.repos.memory_file_queries"]

      def handle(id:)
        file = memory_file_queries.by_id(id)
        return missing("memory file", id) if file.nil?

        Success(
          serialized(Serializers::MemoryFile, file).merge(
            history: serialized(Serializers::MemoryEvent, memory_file_queries.history(id)),
          ),
        )
      end
    end
  end
end
