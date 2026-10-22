# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class NoteEndpoint < Endpoint
      REPLY = Serializers::Note.reference

      include Deps[note_queries: "notes.repos.note_queries"]

      private

      def note(value) = serialized(Serializers::Note, value)

      def settled(result, id, noun: "note")
        case result
          in Success(value) then Success(yield(value))
          in Failure(:not_found) then missing(noun, id)
          in Failure[:invalid, errors] then rejected(errors, Notes::COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
