# frozen_string_literal: true

module API
  module Endpoints
    class ListNoteFolders < NoteFolderEndpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object(
        { count: Helpers::Schema::INTEGER, folders: Helpers::Schema.list(Serializers::NoteFolder.reference) },
      ).freeze

      def handle
        folders = serialized(Serializers::NoteFolder, note_queries.folders)

        Success(count: folders.length, folders:)
      end
    end
  end
end
