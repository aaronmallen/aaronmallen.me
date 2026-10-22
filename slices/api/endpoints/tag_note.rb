# frozen_string_literal: true

module API
  module Endpoints
    class TagNote < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Notes::ID, tag: Helpers::Tags.schema("private") },
        required: %w[id tag],
      }.freeze

      include Deps[tag_note: "notes.operations.tag_note"]

      def handle(id:, tag:)
        name = Blog::Types::Nullable::Tag[tag]
        return invalid(tag: [Helpers::Tags::COMPLAINTS.fetch(Blog::Contract::BLANK)]) if name.nil?
        return invalid(tag: [Helpers::Tags::REFUSAL]) unless Blog::Types::Tag.valid?(name)

        settled(tag_note.call(id, name), id) { note(it) }
      end
    end
  end
end
