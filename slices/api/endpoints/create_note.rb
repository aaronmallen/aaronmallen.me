# frozen_string_literal: true

module API
  module Endpoints
    class CreateNote < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          title: Notes::TITLE.merge(description: "unique among notes, ignoring case; Untitled when you leave it out"),
          body: { type: "string", description: "the note, in Markdown, where [[a title]] links another note" },
          folder_id: Notes::FOLDER,
          tags: { type: "array", items: { type: "string" }, description: "private tags, #{Helpers::Tags::FORMAT}" },
        },
      }.freeze

      include Deps[create_note: "notes.operations.create_note"]

      def handle(**fields) = settled(create_note.call(fields, agent: true), nil) { note(it) }
    end
  end
end
