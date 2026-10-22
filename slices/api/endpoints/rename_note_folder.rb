# frozen_string_literal: true

module API
  module Endpoints
    class RenameNoteFolder < NoteFolderEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Notes::ID, name: Helpers::Schema::STRING },
        required: %w[id name],
      }.freeze

      include Deps[rename_note_folder: "notes.operations.rename_note_folder"]

      def handle(id:, name:) = saved(rename_note_folder.call(id, { name: }), id)
    end
  end
end
