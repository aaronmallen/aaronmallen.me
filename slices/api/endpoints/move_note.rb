# frozen_string_literal: true

module API
  module Endpoints
    class MoveNote < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Notes::ID, folder_id: Notes::FOLDER },
        required: %w[id folder_id],
      }.freeze

      include Deps[move_note: "notes.operations.move_note"]

      def handle(id:, folder_id:) = settled(move_note.call(id, { folder_id: }), id) { note(it) }
    end
  end
end
