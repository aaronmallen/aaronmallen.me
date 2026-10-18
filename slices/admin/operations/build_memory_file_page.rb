# frozen_string_literal: true

module Admin
  module Operations
    class BuildMemoryFilePage
      KIND = Blog::Types::RecordKind["memory_file"]
      LOADED = "loaded"

      include Deps[
        build_memories_page: "operations.build_memories_page",
        list_record_links: "operations.list_record_links",
        memory_file_queries: "agents.repos.memory_file_queries",
      ]

      def call(id, view: nil, form: Blog::Constants::EMPTY_HASH, records: Blog::Constants::EMPTY_HASH)
        file = memory_file_queries.by_id(id)
        return unless file

        {
          file:, form:,
          history: memory_file_queries.history(id),
          loaded: view == LOADED,
          records: list_record_links.call(KIND, id, **records),
          scopes: build_memories_page.scopes([file]),
        }
      end
    end
  end
end
