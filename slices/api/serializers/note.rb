# frozen_string_literal: true

module API
  module Serializers
    class Note < Serializer
      WRITTEN = "marked untrusted when an agent wrote the note"

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: { type: "string", description: WRITTEN },
          body: {
            type: "string",
            description: "the note, in Markdown, where [[a title]] links another note; #{WRITTEN}",
          },
          folder_id: Helpers::Schema.nullable({ type: "integer", description: "its folder; null at the top level" }),
          pinned: Helpers::Schema::BOOLEAN,
          version: { type: "integer", description: "every change raises it; edit_note takes the version you read" },
          tags: Helpers::Schema::TAGS,
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
      tag_names

      def body(note) = note.written_by_agent ? untrusted(note.body) : note.body

      def title(note) = note.written_by_agent ? untrusted(note.title) : note.title
    end
  end
end
