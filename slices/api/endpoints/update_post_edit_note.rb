# frozen_string_literal: true

module API
  module Endpoints
    class UpdatePostEditNote < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Posts::ID,
          edit_id: Posts::ID,
          note: { type: "string", description: "what changed in the published post, and why" },
        },
        required: %w[id edit_id note],
      }.freeze

      REPLY = Serializers::PostEdit.reference

      include Deps[revise_edit_note: "posts.operations.revise_edit_note"]

      def handle(id:, edit_id:, note:)
        case revise_edit_note.call(id, edit_id, { note: })
        in Success(edit) then Success(serialized(Serializers::PostEdit, edit))
        in Failure(:not_found) then not_found(Posts.missing_edit(id, edit_id))
        in Failure[:invalid, errors] then invalid(Posts.form_complaints(errors))
        else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
