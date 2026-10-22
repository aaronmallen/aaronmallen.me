# frozen_string_literal: true

module API
  module Endpoints
    class MoveNoteFolder < NoteFolderEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Notes::ID,
          parent_id: Notes::FOLDER.merge(description: "the folder to move it into; null for the top level"),
        },
        required: %w[id parent_id],
      }.freeze

      include Deps[move_note_folder: "notes.operations.move_note_folder"]

      def handle(id:, parent_id:) = saved(move_note_folder.call(id, { parent_id: }), id)
    end
  end
end
