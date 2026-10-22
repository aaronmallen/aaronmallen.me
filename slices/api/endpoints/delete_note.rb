# frozen_string_literal: true

module API
  module Endpoints
    class DeleteNote < NoteEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_note: "notes.operations.delete_note"]

      def handle(id:) = settled(delete_note.call(id), id) { { id:, deleted: true } }
    end
  end
end
