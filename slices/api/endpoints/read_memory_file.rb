# frozen_string_literal: true

module API
  module Endpoints
    class ReadMemoryFile < MemoryEndpoint
      HISTORY = "a page of changes, newest first"
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          page: Helpers::Paging::PAGE.merge(description: "the page of history"),
          session_id: Memory::LOADS,
        },
        required: ["id"],
      }.freeze

      REPLY = Helpers::Schema.widen(
        Serializers::MemoryFile::SCHEMA,
        history: Helpers::Schema.list(Serializers::MemoryEvent.reference).merge(description: HISTORY),
        partial: Helpers::Schema::BOOLEAN,
      ).then { it.merge(properties: it.fetch(:properties).merge(next_page: Helpers::Schema::INTEGER)) }.freeze

      include Deps[
        memory_file_queries: "agents.repos.memory_file_queries", record_read: "agents.operations.record_read",
      ]

      def handle(id:, page: 1, session_id: nil)
        file = memory_file_queries.by_id(id)
        return missing("memory file", id) if file.nil?

        recorded(record_read.call(session_id, file.id)) { read(file, page) }
      end

      private

      def read(file, page)
        history = memory_file_queries.history(file.id, page_of(page))

        serialized(Serializers::MemoryFile, file).merge(
          history: serialized(Serializers::MemoryEvent, history.rows), **Helpers::Paging.fields(history),
        )
      end
    end
  end
end
