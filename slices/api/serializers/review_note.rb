# frozen_string_literal: true

module API
  module Serializers
    class ReviewNote < Serializer
      SCHEMA = Schema.object(
        {
          body: { type: "string", description: "the note, in Markdown" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      attributes :body, :created_at, :updated_at

      def created_at(note) = stamp(note.created_at)

      def updated_at(note) = stamp(note.updated_at)
    end
  end
end
