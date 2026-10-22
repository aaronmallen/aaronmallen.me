# frozen_string_literal: true

module API
  module Endpoints
    class RemoveNoteFolder < NoteFolderEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, removed: Helpers::Schema::BOOLEAN }).freeze

      include Deps[remove_note_folder: "notes.operations.remove_note_folder"]

      def handle(id:) = settled(remove_note_folder.call(id), id, noun: NOUN) { { id:, removed: true } }
    end
  end
end
