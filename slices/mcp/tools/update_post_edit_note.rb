# frozen_string_literal: true

module MCP
  module Tools
    class UpdatePostEditNote < Base
      description "Replace the note on one past edit of a published post, as the admin editor does. " \
                  "read_post lists each note with its ID. The note takes the same checks the editor makes"
      input_schema(API::Endpoints::UpdatePostEditNote::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:update_post_edit_note, input, server_context)
      end
    end
  end
end
