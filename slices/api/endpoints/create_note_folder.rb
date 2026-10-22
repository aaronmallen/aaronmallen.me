# frozen_string_literal: true

module API
  module Endpoints
    class CreateNoteFolder < NoteFolderEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          path: {
            type: "string",
            description: "its path from the top, such as work/clients; each folder on the path that is missing is made",
          },
        },
        required: %w[path],
      }.freeze

      include Deps["notes.operations.create_note_folder_path"]

      def handle(path:)
        case create_note_folder_path.call(path)
          in Success(nil) then invalid(path: ["name the folder first"])
          in result then saved(result, nil)
        end
      end
    end
  end
end
