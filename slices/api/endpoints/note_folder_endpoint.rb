# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class NoteFolderEndpoint < NoteEndpoint
      NOUN = "note folder"
      REPLY = Serializers::NoteFolder.reference

      private

      def folder(value) = serialized(Serializers::NoteFolder, value)

      def saved(result, id) = settled(result, id, noun: NOUN) { folder(it) }
    end
  end
end
