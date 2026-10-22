# frozen_string_literal: true

module API
  module Endpoints
    class DuplicateNote < NoteEndpoint
      SCHEMA = Helpers::Schema.by_id

      include Deps[duplicate_note: "notes.operations.duplicate_note"]

      def handle(id:) = settled(duplicate_note.call(id), id) { note(it) }
    end
  end
end
