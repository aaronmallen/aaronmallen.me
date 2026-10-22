# frozen_string_literal: true

module API
  module Endpoints
    class RenameNote < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Notes::ID, title: Notes::TITLE },
        required: %w[id title],
      }.freeze
      REPLY = EditNote::REPLY

      include Deps[rename_note: "notes.operations.rename_note"]

      def handle(id:, title:)
        relinked = note_queries.relinks(id, title)

        settled(rename_note.call(id, { title: }, agent: true), id) { note(it).merge(relinked:) }
      end
    end
  end
end
