# frozen_string_literal: true

module API
  module Endpoints
    class Search < Endpoint
      KINDS = Blog::Types::SearchKind.values
      MESSAGE = Blog::Types::SearchKind["message"]
      NOTE = Blog::Types::SearchKind["note"]
      NOTE_ROWS = "note rows need the notes scope"
      SCOPED = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          query: { type: "string", description: "the words to find; quote a phrase or put - before a word to skip it" },
          kind: {
            type: "string",
            enum: KINDS,
            description: "this kind alone; every kind when left out. message needs mail, and note notes",
          },
          page: Helpers::Paging::PAGE,
        },
        required: %w[query],
      }.freeze

      REPLY = Helpers::Schema.paged(
        {
          count: Helpers::Schema::INTEGER,
          results: Helpers::Schema.list(Serializers::SearchHit.reference),
        },
      ).freeze

      include Deps[note_queries: "notes.repos.note_queries", search_queries: "search.repos.search_queries"]

      def handle(query:, scopes:, kind: nil, page: 1)
        refuse_mail(:kind, kind == MESSAGE, scopes) || refuse_notes(kind, scopes) ||
          searched(query, kind, scopes, page)
      end

      private

      def found(query, kind, scopes, page)
        search_queries.search(
          text: query, page: page_of(page), kinds: kinds(kind, scopes),
          open_people: !scopes.include?(OperationTable::CONTACTS),
        )
      end

      def kinds(kind, scopes)
        chosen = kind ? [kind] : KINDS
        chosen -= [MESSAGE] unless mail?(scopes)
        notes?(scopes) ? chosen : chosen - [NOTE]
      end

      def notes?(scopes) = scopes.include?(OperationTable::NOTES)

      def refuse_notes(kind, scopes) = (invalid(kind: [NOTE_ROWS]) if kind == NOTE && !notes?(scopes))

      def searched(query, kind, scopes, page)
        found = found(query, kind, scopes, page)
        notes = found.rows.select { it.kind == NOTE }.map(&:source_id)
        written = notes.empty? ? notes : note_queries.written_by_agent(notes)
        results = serialized(Serializers::SearchHit, found.rows, written:)

        Success(count: results.length, results:, **Helpers::Paging.fields(found))
      end
    end
  end
end
