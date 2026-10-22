# frozen_string_literal: true

module API
  module Endpoints
    class ListNotes < NoteEndpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object(
        { count: Helpers::Schema::INTEGER, notes: Helpers::Schema.list(Serializers::NoteSummary.reference) },
      ).freeze

      def handle
        notes = serialized(Serializers::NoteSummary, note_queries.listed)

        Success(count: notes.length, notes:)
      end
    end
  end
end
