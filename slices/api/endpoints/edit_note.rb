# frozen_string_literal: true

module API
  module Endpoints
    class EditNote < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Notes::ID,
          version: Helpers::Schema::ID.merge(
            description: "the version you read; the edit is refused when the note changed since",
          ),
          title: Notes::TITLE.merge(description: "a new title; [[links]] to the old one in other notes follow it"),
          body: { type: "string", description: "the whole new body, in Markdown" },
          tags: { type: "array", items: { type: "string" }, description: "every private tag the note keeps" },
        },
        required: %w[id version],
      }.freeze
      REPLY = Helpers::Schema.widen(Serializers::Note::SCHEMA, relinked: Notes::RELINKED).freeze

      include Deps[edit_note: "notes.operations.edit_note"]

      def handle(id:, **fields)
        relinked = fields.key?(:title) ? note_queries.relinks(id, fields[:title]) : 0

        settled(edit_note.call(id, fields, agent: true), id) { note(it).merge(relinked:) }
      end
    end
  end
end
