# frozen_string_literal: true

module Admin
  module Operations
    class BuildMemoryFilePage
      KIND = Blog::Types::RecordKind["memory_file"]
      EMPTY = Blog::Constants::EMPTY_HASH
      LOADED = "loaded"

      include Deps[
        "settings",
        build_memories_page: "operations.build_memories_page",
        list_record_links: "operations.list_record_links",
        memory_file_queries: "agents.repos.memory_file_queries",
      ]

      def call(id, page: first_page, view: nil, form: EMPTY, records: EMPTY)
        file = memory_file_queries.by_id(id)
        return unless file

        history = memory_file_queries.history(id, page)

        {
          file:, form:, history:,
          history_count: memory_file_queries.history_count(id),
          history_marks: memory_file_queries.history_marks(history.rows),
          loaded: view == LOADED,
          records: list_record_links.call(KIND, id, **records),
          scopes: build_memories_page.scopes([file]),
        }
      end

      private

      def first_page = Blog::Structs::Page.new(number: 1, size: settings.page_size[:admin])
    end
  end
end
