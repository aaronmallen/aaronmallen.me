# frozen_string_literal: true

module API
  module Endpoints
    class DescribeNoteFolder < NoteFolderEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Notes::ID,
          description: { type: "string", description: "what the folder holds; an empty string clears it" },
        },
        required: %w[id description],
      }.freeze

      include Deps[describe_note_folder: "notes.operations.describe_note_folder"]

      def handle(id:, description:) = saved(describe_note_folder.call(id, { description: }), id)
    end
  end
end
