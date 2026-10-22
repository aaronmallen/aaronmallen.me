# frozen_string_literal: true

module API
  module Endpoints
    class SearchNotes < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          query: {
            type: "string",
            description: "words to find in titles, bodies, folder paths and tag names, or #tag for the notes it tags",
          },
        },
        required: %w[query],
      }.freeze
      REPLY = ListNotes::REPLY

      include Deps[search_notes: "notes.operations.search_notes"]

      def handle(query:)
        notes = serialized(Serializers::NoteSummary, search_notes.call(query))

        Success(count: notes.length, notes:)
      end
    end
  end
end
