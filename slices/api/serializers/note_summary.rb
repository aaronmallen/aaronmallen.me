# frozen_string_literal: true

module API
  module Serializers
    class NoteSummary < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: { type: "string", description: Note::WRITTEN },
          folder_id: Helpers::Schema.nullable({ type: "integer", description: "its folder; null at the top level" }),
          pinned: Helpers::Schema::BOOLEAN,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :updated_at

      def title(note) = note.written_by_agent ? untrusted(note.title) : note.title
    end
  end
end
