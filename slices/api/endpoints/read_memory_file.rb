# frozen_string_literal: true

module API
  module Endpoints
    class ReadMemoryFile < MemoryEndpoint
      ASKED = "true adds a page of the file's changes; false when left out"
      FILE = Serializers::MemoryFile::SCHEMA
      HISTORY = "a page of changes, newest first"
      SCHEMA = {
        additionalProperties: false,
        properties: {
          history: Helpers::Schema::BOOLEAN.merge(description: ASKED),
          id: Helpers::Schema::ID,
          page: Helpers::Paging::PAGE.merge(description: "the page of history, with history true"),
          session_id: Memory::LOADS,
        },
        required: ["id"],
      }.freeze

      REPLY = FILE.merge(
        properties: FILE.fetch(:properties).merge(
          history: Helpers::Schema.list(Serializers::MemoryEvent.reference).merge(description: HISTORY),
          next_page: Helpers::Schema::INTEGER,
          partial: Helpers::Schema::BOOLEAN,
        ),
      ).freeze

      include Deps[
        memory_file_queries: "agents.repos.memory_file_queries", record_read: "agents.operations.record_read",
      ]

      def handle(id:, history: false, page: 1, session_id: nil)
        file = memory_file_queries.by_id(id)
        return missing("memory file", id) if file.nil?

        recorded(record_read.call(session_id, file.id)) do
          read = serialized(Serializers::MemoryFile, file)
          history ? read.merge(history_page(file, page)) : read
        end
      end

      private

      def history_page(file, page)
        history = memory_file_queries.history(file.id, page_of(page))

        { history: serialized(Serializers::MemoryEvent, history.rows), **Helpers::Paging.fields(history) }
      end
    end
  end
end
