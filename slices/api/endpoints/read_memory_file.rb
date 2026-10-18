# frozen_string_literal: true

module API
  module Endpoints
    class ReadMemoryFile < MemoryEndpoint
      HISTORY = "a page of changes, newest first"
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Helpers::Schema::ID, page: Helpers::Paging::PAGE.merge(description: "the page of history") },
        required: ["id"],
      }.freeze

      REPLY = Helpers::Schema.widen(
        Serializers::MemoryFile::SCHEMA,
        history: Helpers::Schema.list(Serializers::MemoryEvent.reference).merge(description: HISTORY),
        partial: Helpers::Schema::BOOLEAN,
      ).then { it.merge(properties: it.fetch(:properties).merge(next_page: Helpers::Schema::INTEGER)) }.freeze

      include Deps[memory_file_queries: "agents.repos.memory_file_queries"]

      def handle(id:, page: 1)
        file = memory_file_queries.by_id(id)
        return missing("memory file", id) if file.nil?

        history = memory_file_queries.history(id, page_of(page))

        Success(
          serialized(Serializers::MemoryFile, file).merge(
            history: serialized(Serializers::MemoryEvent, history.rows), **Helpers::Paging.fields(history),
          ),
        )
      end
    end
  end
end
