# frozen_string_literal: true

module API
  module Endpoints
    class PinNote < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Notes::ID,
          pinned: { type: "boolean", description: "true pins it to the top of the notes tab; false unpins it" },
        },
        required: %w[id pinned],
      }.freeze

      include Deps[pin_note: "notes.operations.pin_note"]

      def handle(id:, pinned:) = settled(pin_note.call(id, { pinned: }), id) { note(it) }
    end
  end
end
